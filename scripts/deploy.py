from brownie import accounts, MultiSigWallet

def test_msig():
    person1, person2, person3, person4, *_ = accounts

    multisig = MultiSigWallet.deploy([person1, person2, person3], 2, {"from": person1})
    
    tx = multisig.submit(person4, 0.001, '', {"from": person2})
    tx.wait(1)

    tx = multisig.approve(0, {"from": person1})
    tx.wait(1)

    tx = multisig.approve(0, {"from": person3})
    tx.wait(1)

    tx = multisig.execute(0, {"from": person2})
    tx.wait(1)

def main():
    test_msig()