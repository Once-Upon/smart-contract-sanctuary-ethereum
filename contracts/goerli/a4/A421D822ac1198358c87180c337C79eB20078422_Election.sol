/**
 *Submitted for verification at Etherscan.io on 2022-11-09
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Election {
    uint idenCandidates = 0;
    uint idenAmphoras = 0;
    uint counter = 0;

    struct Candidate {
        uint identyfier;
        string group;
        uint voteCount;
    }

    struct Vote {
        uint counter;
        string code;
        address addr;
    }

    struct Amphora {
        string name;
        address addr;        
    }

    Amphora[] public amphoras;
    Candidate[] public candidates;
    mapping (uint => Vote) public votes;

    event ballot(uint _choise, string _code);
    event addedAmphora(string _name);
    event addedCandidate(string _group);

    function newCandidate(string memory _group) public {
        candidates[idenCandidates] = Candidate(idenCandidates + 1, _group, 0);
        idenCandidates++;
        emit addedCandidate(_group);
    }

    function newAmphora(string memory _name, address _addrr) public {
        amphoras[idenAmphoras] = Amphora(_name, _addrr);
        idenAmphoras++;
        emit addedAmphora(_name);
    }

    function validateAmphora(address _from) private view returns (bool) {
        bool result = false;

        for(uint i = 0; i < amphoras.length; i++){
            if(amphoras[i].addr == _from)
                result = true;
        }

        return result;
    } 

    function validateOption(uint16 _option) private returns (bool) {
        bool result = false;

        for(uint i = 0; i < candidates.length; i++){
            if(candidates[i].identyfier == _option)
                candidates[i].voteCount++;
                result = true;
        }
        
        return result;
    }

    function voting(uint16 _option, string memory _code) public {
        require(validateAmphora(msg.sender), "Usted esta ingresando desde una Amfora no registrada");

        require(validateOption(_option), "La opcion que usted eligio no es valida");
        
        for (uint256 i = 0; i < candidates.length; i++) {
            if (candidates[i].identyfier == _option) {
                candidates[i].voteCount++;
                votes[counter] = Vote(counter + 1, _code, msg.sender);
                counter ++;
                emit ballot(_option, _code);
            }
        }
    }    
}