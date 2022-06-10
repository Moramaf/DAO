//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./TokenERC20.sol";

// Необходимы реализовать смарт контракт, который будет вызывать сигнатуру функции посредством голосования пользователей.
// -Написать контракт DAO
// -Написать полноценные тесты к контракту
// -Написать скрипт деплоя
// -Задеплоить в тестовую сеть
// -Написать таск на vote, addProposal, finish, deposit.
// -Верифицировать контракт
// Требования
// -Для участия в голосовании пользователям необходимо внести  токены для голосования. 
// -Вывести токены с DAO, пользователи могут только после окончания всех голосований, в которых они участвовали. 
// -Голосование может предложить только председатель.
// -Для участия в голосовании пользователю необходимо внести депозит, один токен один голос. 
// -Пользователь может участвовать в голосовании одними и теми же токенами, то есть пользователь внес 100 токенов он может участвовать в голосовании №1 всеми 100 токенами и в голосовании №2 тоже всеми 100 токенами.
// -Финишировать голосование может любой пользователь по прошествии определенного количества времени установленном в конструкторе.

contract DAO {

address public chairPerson;
TokenERC20 public voteToken;
uint public minQuorum;
uint public debatingPeriod; // days

struct Voter {
        uint deligatedVotes; // weight is accumulated by delegation
        bool voted;  // if true, that person already voted
        address delegate; // person delegated to
        bool vote;   // index of the voted proposal
    }

mapping(address=>uint) public balances;
mapping(uint => mapping(address => Voter)) public votedVoters; //votingID =>voter=>voted

//votings
struct Voting {
    string name;
    //callData
    address recipient;
    string description;
    uint startTime;
    uint noVotes;
    uint yesVotes;
    bool ended;
}
uint private votingID;
mapping(uint=> Voting) public votings; //votingID => Voting

event Deposit(address indexed _voter, uint _amount);
event Vote(address indexed _voter, uint _amount, bool indexed _vote);
event Finish(uint indexed _votingId, bool _result);
event Deligate(address indexed from,address indexed to);


constructor(address _chairPerson, address _voteToken,uint _minQuorum, uint _debatingPeriod) {
    chairPerson = _chairPerson;
    voteToken = TokenERC20(_voteToken);
    minQuorum = _minQuorum;
    debatingPeriod = _debatingPeriod;
}

modifier isVotingEnded(uint _votingId) {
    require(!votings[_votingId].ended, "voting ended!");
    _;
}
modifier isVoterVoted(uint _votingId) {
    require(!votedVoters[_votingId][msg.sender].voted, "voter already voted!");
    _;
}

function deposit(uint _amount) external {
    voteToken.transferFrom(msg.sender, address(this), _amount); //should be approved
    balances[msg.sender] = _amount;
    emit Deposit(msg.sender, _amount);
}

function addProposal(string memory _name,/*callData, */ address _recipient, string memory _description) external {
    require(msg.sender == chairPerson, "Caller not a Chair Person");
    votings[votingID].name = _name;
    //votings[votingID].callData
    votings[votingID].recipient = _recipient;
    votings[votingID].description = _description;
    votings[votingID].startTime = block.timestamp;
    votingID++;
}

function vote(uint _votingId, bool _vote) external isVotingEnded(_votingId) isVoterVoted(_votingId) {
    uint amount_ = balances[msg.sender] + votedVoters[_votingId][msg.sender].deligatedVotes;
    if(_vote == true) {
        votings[_votingId].yesVotes += amount_;
    } else {
        votings[_votingId].noVotes += amount_;
    }
    votedVoters[_votingId][msg.sender].voted = true;
    emit Vote(msg.sender, amount_, _vote);
}

function finishProposal(uint _votingId) public returns (bool) {
    require(!votings[_votingId].ended, "Voting is over!");
    require(block.timestamp > (votings[_votingId].startTime + (debatingPeriod * 1 days)), "Debating period not over!");
    uint votings_ = votings[_votingId].noVotes + votings[_votingId].yesVotes;
    require(minQuorum < votings_, "minimum quarum did not reach!");
    if(votings[_votingId].noVotes > votings[_votingId].yesVotes) {
        votings[_votingId].ended = true;
        emit Finish(_votingId, false);
        return false;
    } else {
        votings[_votingId].ended = true;
        // execution callData
        emit Finish(_votingId, true);
        return true;
    }
}

    function delegate(uint _votingId, address to) public isVotingEnded(_votingId) isVoterVoted(_votingId) {
        require(to != msg.sender, "Self-delegation is disallowed.");

        while (votedVoters[_votingId][to].delegate != address(0)) {
            to = votedVoters[_votingId][to].delegate;
            require(to != msg.sender, "Found loop in delegation.");  // found a loop in the delegation, not allowed.
        }
        votedVoters[_votingId][msg.sender].voted = true;
        votedVoters[_votingId][to].delegate = to;
        if (votedVoters[_votingId][to].voted) {
             if(votedVoters[_votingId][to].vote == true) { // If the delegate already voted,directly add to the number of votes
                votings[_votingId].yesVotes += balances[msg.sender];
            } else {
                votings[_votingId].noVotes += balances[msg.sender];
            }
        } else {
            votedVoters[_votingId][to].deligatedVotes += balances[msg.sender]; // If the delegate did not vote yet,add to her weight.
        }
        emit Deligate(msg.sender, to);
    }

function withdraw() external {
    // как узнать какие еще не закончились аукционы?
    uint amount_ = balances[msg.sender];
    voteToken.transfer(msg.sender,amount_);
}

}