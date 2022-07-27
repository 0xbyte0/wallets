// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

/// @author 0xosas
/// @notice A simple implementation of a multi signature wallet
contract MultiSigWallet{

    /// Events
    event Deposit(address indexed sender, uint amount);
    event SubmitTransaction(uint indexed txId);
    event ApproveTransaction(address indexed owner, uint indexed txId);
    event RefuseTransaction(address indexed owner, uint indexed txId);
    event ExecuteTransaction(uint indexed txId);

    /// Storage

    struct Transaction {
        address to;
        bool executed;
        uint256 value;
        bytes data;
    }

    uint256 public minApproval;
    
    mapping(address => bool) isOwner;
    mapping(uint => mapping(address => bool)) public approveBy;

    address[] public owners;
    Transaction[] public transactions;



    constructor(address[] memory _owners, uint _minApproval) payable {
        require(_owners.length > 1, "owners required");
        require(_minApproval > 0, "invalid min approval");
        require(_owners.length >= _minApproval, "invalid min approval");

        unchecked{
            for (uint i=0; i < _owners.length; i++){
                address owner = _owners[i];
                require(owner != address(0), "invalid address");
                require(!isOwner[owner], "owners must be unique");

                isOwner[owner] = true;
                owners.push(owner);
            }
        }

        minApproval = _minApproval;
    }

    receive() external payable{
        emit Deposit(msg.sender, msg.value);
    }

    /// Modifiers

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    function transactionExists(uint _transactionId) public view returns (bool){
        return _transactionId < transactions.length;
    }

    modifier notExecuted(uint _transactionId) {
        require(!transactions[_transactionId].executed, "transaction already executed");
        _;
    }

    /// @notice Adding a Transaction, waiting for approval
    /// @param _to is where the money would be transfered to
    /// if approved
    /// @param _value is the amount money to be transfered
    /// @param _data is transaction data
    function submit(address _to, uint _value, bytes calldata _data) external onlyOwner{
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false
            })
        );

        emit SubmitTransaction(transactions.length - 1);
    }

    /// @notice allows an owner to approve a transaction
    /// @param _transactionId is the ID of the transaction
    function approve(uint _transactionId) 
        external 
        onlyOwner 
        notExecuted(_transactionId) 
    {
        require(transactionExists(_transactionId), "transaction does not exists");
        approveBy[_transactionId][msg.sender] = true;
        emit ApproveTransaction(msg.sender, _transactionId);
    }

    
    /// @notice gives you the total number of approvals of
    /// a single transaction
    /// @param _transactionId is the ID of the transaction
    /// made public for testing
    function getApprovalCount(uint _transactionId) public view returns (uint count) {
        /// count overflow is impossible as it cannot exceed `owners.length`
        unchecked {
            for(uint i=0; i < owners.length; i++) {
                if(approveBy[_transactionId][owners[i]]) {
                    count++;
                }
            }
        }
    }

    /// @notice executes a transaction if its has the minimal approvals
    /// @param _transactionId is the ID of the transaction
    function execute(uint _transactionId) 
        external 
        notExecuted(_transactionId) 
    {
        require(transactionExists(_transactionId), "transaction does not exists");
        require(getApprovalCount(_transactionId) >= minApproval, "not enough approvals");

        Transaction storage transaction = transactions[_transactionId];

        transaction.executed = true;
        (bool success,) = transaction.to.call{ value: transaction.value }(transaction.data);

        require(success);
        emit ExecuteTransaction(_transactionId);
    }

    /// @notice refuses a transaction
    /// @param _transactionId is the ID of the transaction
    function refuse(uint _transactionId) 
        external 
        onlyOwner 
        notExecuted(_transactionId) 
    {
        require(transactionExists(_transactionId), "transaction does not exists");
        require(approveBy[_transactionId][msg.sender], "transaction not approved");

        approveBy[_transactionId][msg.sender] = false;
        emit RefuseTransaction(msg.sender, _transactionId);
    }

    function balance() external view onlyOwner returns(uint){
        return address(this).balance;
    }
}