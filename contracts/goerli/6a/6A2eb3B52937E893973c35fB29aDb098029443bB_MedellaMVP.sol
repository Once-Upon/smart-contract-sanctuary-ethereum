/**
 *Submitted for verification at Etherscan.io on 2022-09-06
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract MedellaMVP {
    address public owner;
    uint256 public patientCount;

    struct Patient {
        uint256 patientId; // generated by contract
        string cypherText; // encrypted basic details of patient
        uint256 fileCount;
    }

    struct File {
        uint256 id; // generated by contract
        string data; // encrypted base 64 string
        string cypherText; // encrypted details of file (name, description, type, timestamp, etc)
    }

    mapping (uint256 => Patient) public patients;
    mapping (uint256 => mapping (uint256 => File)) public file;

    event AddPatient(uint256 indexed patientId, string cypherText);
    event UpdatePatient(uint256 indexed patientId, string cypherText);
    event AddFile(uint256 indexed patientId, uint256 indexed fileId, string fileData, string fileCypherText);


    function addPatient(string memory _cypherText) external {
        patients[patientCount].patientId = patientCount;
        patients[patientCount].cypherText = _cypherText;

        emit AddPatient(patientCount, _cypherText);

        patientCount += 1;
    }  

    function updatePatient(uint256 _id, string memory _cypherText) external {
        patients[_id].cypherText = _cypherText;

        emit UpdatePatient(_id, _cypherText);
    }

    function addFile(uint256 _patientid, string memory _fileData, string memory _fileCypherText) external {
        uint256 fileId = patients[_patientid].fileCount;

        file[_patientid][fileId].id = patients[_patientid].fileCount;
        file[_patientid][fileId].data = _fileData;
        file[_patientid][fileId].cypherText = _fileCypherText;

        emit AddFile(_patientid, patients[_patientid].fileCount, _fileData, _fileCypherText);

        patients[_patientid].fileCount += 1;
    }
}