/**
 *Submitted for verification at Etherscan.io on 2023-06-14
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;


error DB_ERROR();

contract Regitration {
    address[] public addressVefication;

    address[] public Verif;
    mapping(address => address) f;
    // string[] public Ref;



    address my_address = 0x113F3979D7774147D39AB7E097D23b6E5D567D39;

    function push(address i) public payable {
        Verif.push(i);
    }

    function addresVerification() public payable {

        for(uint i = 0; i < Verif.length; i++) {
            if (msg.sender != Verif[i]) {
                revert DB_ERROR();
            } else {
                addressVefication.push(msg.sender);
        }
        }
    }



    // Функция для добавление адресса в массив Verif - Ready
    // Сделать кастомную ошибку если адреса нету в массиве Verif
    // Выаодить на фронтенд кастомную ошибку 
    // Сделать триггер если аднес не зареган для переноса на страницу ввода рефки
    // Если зареган то на главную 
}