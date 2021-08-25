import asyncio
import json

from tonclient.types import KeyPair

from utils import send_tons_with_se_giver,\
    send_tons_with_multisig, client
from validator_contract import ValidatorContract
from elector_contract import ElectorContract
from depool_mock_contract import DePoolMockContract


CONFIG_PATH = './off-chain/config.json'


with open(CONFIG_PATH) as f:
    config = json.load(f)


async def main():
    # prepare elector and depool
    e_contract = ElectorContract()
    await e_contract.create(
        dir='./artifacts',
        name='Elector',
        client=client,
        keypair=KeyPair(
            public=config['elector']['public_key'],
            secret=config['elector']['private_key'],
        )
    )

    d_contract = DePoolMockContract()
    await d_contract.create(
        dir='./artifacts',
        name='DePoolMock',
        client=client,
        keypair=KeyPair(
            public=config['depool']['public_key'],
            secret=config['depool']['private_key'],
        )
    )

    # init Validator object
    v_contract = ValidatorContract()
    await v_contract.create(
        dir='./artifacts',
        name='Validator',
        client=client,
    )

    # send tons
    if config['use_se_giver']:
        await send_tons_with_se_giver(await v_contract.address(), config['validator']['start_balance'])
    else:
        await send_tons_with_multisig(config['multisig'], config['validator']['start_balance'])

    # deploy
    await v_contract.deploy(
        elector_address=config['elector']['address'],
        validation_start_time=str(config['elector']['validation_start_time']),
        validation_duration=str(config['elector']['validation_duration']),
        depools={config['depool']['address']: True},
        owner='0:' + '0'*64,
        # TODO top_up settings
    )

    # TODO transfer DePool stake to validator
    await d_contract.transfer_stake(
        dest=await v_contract.address(),
        amount=20000 * 10**9,
    )
    await asyncio.sleep(1)

    # sign-up
    await v_contract.sign_up()

    await v_contract.process_events()
    await e_contract.process_events()

    # update config
    config['validator']['address'] = await v_contract.address()
    config['validator']['public_key'] = v_contract._keypair.public
    config['validator']['private_key'] = v_contract._keypair.secret
    with open(CONFIG_PATH, 'w') as f:
        json.dump(config, f, indent=4)

if __name__ == '__main__':
    asyncio.run(main())