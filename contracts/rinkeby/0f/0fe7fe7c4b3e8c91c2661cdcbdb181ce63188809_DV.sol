// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title: Daly Ventures
/// @author: manifold.xyz

import "./ERC721Creator.sol";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        //
//                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        //
//    [size=9px][font=monospace][color=#212121]█[/color][color=#2b2b2b]█[/color][color=#3a3a3a]█[/color][color=#3a3a3a]████████████████████████████████████████████████████████████████████████████████████████████████[/color][color=#020202]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   //
//    [color=#0c0c0c]█                                                                                                  █[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         //
//    [color=#0c0c0c]█       [/color][color=#7c5a5a]█ [/color][color=#7d2d2d]█[/color][color=#a80506]█ [/color][color=#7f4040]█[/color][color=#7b6c6c]▄                                                                      [/color][color=#7a6d6d]▄[/color][color=#824141]█ [/color][color=#b50102]█[/color][color=#715e5e]█ [/color][color=#7e5959]█       [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            //
//    [color=#0c0c0c]█     [/color][color=#736263]▓ [/color][color=#b70202]█[/color][color=#811313]█[/color][color=#990505]█[/color][color=#b50203]█ [/color][color=#b00203]█[/color][color=#980909]█                                                                    [/color][color=#756c6c]▄ █[/color][color=#a70202]█[/color][color=#7c2a2a]█[/color][color=#be0101]█[/color][color=#674343]█[/color][color=#820202]█[/color][color=#b90102]█[/color][color=#767373]─      [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         //
//    [color=#0c0c0c]█    [/color][color=#763a3a]█[/color][color=#b70102]█[/color][color=#5e3f3e]██[/color][color=#7c2c2c]█[/color][color=#ac0202]█[/color][color=#b60102]█[/color][color=#4e4545]███[/color][color=#726f6f]▄                                                                  [/color][color=#716060]█[/color][color=#b90102]█[/color][color=#693f40]██[/color][color=#970405]█[/color][color=#821212]█[/color][color=#bc0101]█[/color][color=#642d2e]█[/color][color=#860203]█[/color][color=#cc0001]█[/color][color=#6e4747]█      [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    //
//    [color=#0c0c0c]█    [/color][color=#9b0405]█[/color][color=#a00102]█[/color][color=#7e292a]█[/color][color=#ca0001]██[/color][color=#c60102]██[/color][color=#413333]███[/color][color=#6b6363]█                                                                  [/color][color=#802829]█[/color][color=#bb0101]█[/color][color=#543838]██[/color][color=#980b0b]█[/color][color=#9c0404]█[/color][color=#cc0001]█[/color][color=#762828]█[/color][color=#910102]█[/color][color=#c20001]█[/color][color=#713d3d]█      [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           //
//    [color=#0c0c0c]█    [/color][color=#b20101]█[/color][color=#ba0202]█[/color][color=#9a0707]█████[/color][color=#a70404]█[/color][color=#c50001]█[/color][color=#c30102]█[/color][color=#706f6f]▄[/color][color=#776d6d]▄[/color][color=#873a3a]█                                       [/color][color=#6a6a6a]▌[/color][color=#515050]█[/color][color=#303030]█[/color][color=#1f1e1e]█[/color][color=#737373]─                    [/color][color=#891718]█[/color][color=#c80001]█[/color][color=#810e0e]█████[/color][color=#b00405]█[/color][color=#bb0101]█[/color][color=#cc0001]█[/color][color=#644747]█ [/color][color=#864141]██   [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        //
//    [color=#0c0c0c]█    [/color][color=#b00101]█[/color][color=#cc0001]█[/color][color=#cc0001]██[/color][color=#b80102]█[/color][color=#b50102]███[/color][color=#cb0001]██ [/color][color=#8e0607]██[/color][color=#736e6e]▄                            [/color][color=#121010]█[/color][color=#050404]█[/color][color=#0d0c0c]█[/color][color=#1e1d1d]█[/color][color=#282626]█[/color][color=#242424]█[/color][color=#1e1d1d]█[/color][color=#141313]█[/color][color=#060606]█[/color][color=#010000]█[/color][color=#010000]███[/color][color=#0b0909]█[/color][color=#727272]┐     [/color][color=#767676],              [/color][color=#871718]█[/color][color=#cc0001]█[/color][color=#cc0001]███[/color][color=#b60102]█[/color][color=#b60102]██[/color][color=#ca0001]█[/color][color=#ca0001]█[/color][color=#686363]█[/color][color=#6c2525]█[/color][color=#cb0001]█[/color][color=#724444]█   [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                           //
//    [color=#0c0c0c]█    [/color][color=#a60102]█[/color][color=#cc0001]█[/color][color=#ca0001]███████[/color][color=#950203]█[/color][color=#b00304]█[/color][color=#c30102]█[/color][color=#891c1d]█                       [/color][color=#6d6d6d]▌ [/color][color=#434242]█[/color][color=#383737]█[/color][color=#3d3c3c]█[/color][color=#1a1a1a]█[/color][color=#010000]█[/color][color=#010000]█[/color][color=#0e0d0d]█████████████[/color][color=#393939]█  [/color][color=#717171]╓[/color][color=#232121]█[/color][color=#302d2d]▌              [/color][color=#821e1f]█[/color][color=#cc0001]█[/color][color=#cc0001]███████[/color][color=#af0102]█[/color][color=#9f0809]█[/color][color=#c60001]██[/color][color=#746e6e]▀   [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            //
//    [color=#0c0c0c]█    [/color][color=#841415]█[/color][color=#cc0001]█[/color][color=#cc0001]█[/color][color=#af0102]██[/color][color=#ae0202]█[/color][color=#cc0001]█[/color][color=#cc0001]███[/color][color=#961212]█[/color][color=#705d5e]█    [/color][color=#666666]▓[/color][color=#4e4e4e]█[/color][color=#616161]██[/color][color=#2f2e2e]█[/color][color=#434242]█[/color][color=#6c6c6c]▀█[/color][color=#666666]█[/color][color=#636363]█[/color][color=#6b6b6b]▌        [/color][color=#0c0b0b]█[/color][color=#020000]█[/color][color=#020000]█████[/color][color=#272525]█[/color][color=#191919]█[/color][color=#3c3c3c]█[/color][color=#5e5e5e]█[/color][color=#181717]█[/color][color=#010000]█[/color][color=#010000]█████████[/color][color=#4e4e4e]█  [/color][color=#070606]█[/color][color=#030000]█[/color][color=#010101]█[/color][color=#353434]█    [/color][color=#5f5e5e]█[/color][color=#1d1b1b]█[/color][color=#020101]█[/color][color=#020000]█[/color][color=#060404]█[/color][color=#221f1f]█[/color][color=#3c3b3b]█[/color][color=#484747]█[/color][color=#696969]▌[/color][color=#6d3e3e]█[/color][color=#cc0001]█[/color][color=#cc0001]██[/color][color=#b20102]█[/color][color=#a20202]█[/color][color=#c80001]█[/color][color=#cc0001]███[/color][color=#a90606]█      [/color][color=#000000]█[/color]    //
//    [color=#0c0c0c]█    [/color][color=#6c5a5a]█[/color][color=#c40101]█[/color][color=#cc0001]██████[/color][color=#991010]█    [/color][color=#656565]▓[/color][color=#656565]█[/color][color=#414141]█[/color][color=#4a4949]█[/color][color=#737474],[/color][color=#343332]█[/color][color=#000000]█[/color][color=#000000]██[/color][color=#242323]█[/color][color=#494747]█[/color][color=#171616]█[/color][color=#343333]█[/color][color=#1e1d1d]█[/color][color=#717171]╓ [/color][color=#737373]▄     [/color][color=#403f3f]█[/color][color=#010000]█[/color][color=#000000]█████████████████████[/color][color=#4b4b4b]█[/color][color=#696868]▓[/color][color=#010000]█[/color][color=#020000]█████[/color][color=#363535]█[/color][color=#717171]j[/color][color=#020000]█[/color][color=#010000]████[/color][color=#252424]▀[/color][color=#484747]█[/color][color=#6c6c6c]▀  [/color][color=#aa0405]█[/color][color=#cc0001]█[/color][color=#ca0001]█████[/color][color=#a80606]█[/color][color=#7b3f40]█       [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                        //
//    [color=#0c0c0c]█     [/color][color=#663838]█[/color][color=#ad0101]█[/color][color=#b70102]█[/color][color=#ca0001]████    [/color][color=#484848]█ [/color][color=#6e6e6e]▄[/color][color=#070606]█[/color][color=#000000]█[/color][color=#000000]█[/color][color=#181818]████████[/color][color=#0a0808]█ [/color][color=#000000]█[/color][color=#000000]█[/color][color=#484848]█    [/color][color=#292828]█[/color][color=#000000]█[/color][color=#010000]████[/color][color=#333232]█ [/color][color=#2a2a2a]█[/color][color=#010000]█[/color][color=#010000]████████████[/color][color=#0b0a09]█  [/color][color=#2b2a2a]█[/color][color=#000000]█[/color][color=#020000]█████[/color][color=#0c0b0b]█████[/color][color=#161313]█     [/color][color=#6d6161]█[/color][color=#ab0102]█[/color][color=#ab0102]█[/color][color=#cc0001]██[/color][color=#c80001]██         [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                  //
//    [color=#0c0c0c]█      [/color][color=#922b2c]█[/color][color=#922626]█[/color][color=#8b2525]███[/color][color=#902c2d]█[/color][color=#6c6968]▌   [/color][color=#484848]█[/color][color=#535353]█ [/color][color=#2f2e2e]█[/color][color=#222121]▀[/color][color=#030303]█[/color][color=#010000]████████[/color][color=#373535]█[/color][color=#282828]█[/color][color=#000000]█[/color][color=#000000]█[/color][color=#464646]█     [/color][color=#3e3e3e]█[/color][color=#383737]█[/color][color=#424141]█[/color][color=#0a0a0a]█[/color][color=#4c4c4c]█ [/color][color=#252424]█[/color][color=#010000]█[/color][color=#000000]████████████[/color][color=#080606]█[/color][color=#434243]█   [/color][color=#636363]█[/color][color=#2d2c2c]█[/color][color=#070606]█[/color][color=#020000]█[/color][color=#010000]████████[/color][color=#414040]█    [/color][color=#6f6c6c]▀[/color][color=#912d2e]█[/color][color=#922727]█[/color][color=#922525]█[/color][color=#712425]██[/color][color=#922a2a]█         [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                        //
//    [color=#0c0c0c]█                 [/color][color=#6c6c6c]▌[/color][color=#444343]█[/color][color=#2f2e2f]█[/color][color=#212020]█[/color][color=#050404]█[/color][color=#020000]█[/color][color=#010000]███████[/color][color=#060505]████[/color][color=#060606]█[/color][color=#232323]█[/color][color=#282828]██[/color][color=#181818]█[/color][color=#090909]█[/color][color=#020202]█[/color][color=#1f1f1f]█[/color][color=#242424]█[/color][color=#0d0d0d]█ [/color][color=#202020]█[/color][color=#050303]█[/color][color=#000000]████████████[/color][color=#3e3d3d]█      [/color][color=#484747]█[/color][color=#060505]█[/color][color=#020000]█[/color][color=#000000]█████████                    █[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          //
//    [color=#0c0c0c]█                  [/color][color=#474646]█[/color][color=#010000]█[/color][color=#000000]██[/color][color=#060505]███████████[/color][color=#181818]█[/color][color=#202020]█[/color][color=#2e2e2e]█[/color][color=#434343]█ [/color][color=#717171]┘ [/color][color=#6e6e6e]╠[/color][color=#3a3a3a]█[/color][color=#151414]█[/color][color=#030202]█[/color][color=#111010]████████████████[/color][color=#4d4d4d]█     [/color][color=#010000]█[/color][color=#030000]████[/color][color=#6c6c6c]▌ [/color][color=#3f3f3f]█[/color][color=#000000]█[/color][color=#010000]███[/color][color=#727172]═                   █[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               //
//    [color=#0c0c0c]█                 ▄[/color][color=#606060]█[/color][color=#616161]█[/color][color=#696969]▌[/color][color=#6f6f6f]▄[/color][color=#2d2c2c]█[/color][color=#010000]█[/color][color=#010000]█████████[/color][color=#050404]█[/color][color=#424140]█  [/color][color=#747474]─[/color][color=#494949]█[/color][color=#191717]█[/color][color=#060505]█[/color][color=#131212]█[/color][color=#101010]█[/color][color=#020000]█[/color][color=#010000]█[/color][color=#1a1919]█[/color][color=#0f0e0e]█[/color][color=#010000]█[/color][color=#020000]██████████████[/color][color=#1f1e1e]█[/color][color=#404040]█[/color][color=#6b6a6a]▌ [/color][color=#3d3c3c]█[/color][color=#1b1919]█[/color][color=#120f0f]█[/color][color=#050404]█[/color][color=#020000]█[/color][color=#141212]█ [/color][color=#656666]▓[/color][color=#010000]█[/color][color=#030000]██[/color][color=#181616]█                    █[/color]                                                                                                                                                                                                                                                                                                                                                                                                           //
//    [color=#0c0c0c]█                     [/color][color=#6b6b6b]▀[/color][color=#636262]█ [/color][color=#050404]█[/color][color=#000000]█[/color][color=#000000]██████████[/color][color=#373636]█[/color][color=#6a6a6a]▌[/color][color=#6d6d6d]▌      ▓[/color][color=#343333]█[/color][color=#050404]█[/color][color=#010000]██[/color][color=#010000]███████[/color][color=#131111]█[/color][color=#707070]╙ [/color][color=#494848]█[/color][color=#464545]██[/color][color=#535353]█[/color][color=#6c6c6c]▀      [/color][color=#4a4949]█▌[/color][color=#0e0d0d]█[/color][color=#000000]█[/color][color=#000000]█[/color][color=#21201f]█                     █[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        //
//    [color=#0c0c0c]█                       [/color][color=#393838]█[/color][color=#454444]█[/color][color=#262425]█[/color][color=#010000]█[/color][color=#000000]█████████████[/color][color=#171717]█[/color][color=#393838]█[/color][color=#3e3d3d]█[/color][color=#292828]█[/color][color=#0a0a0a]█[/color][color=#010000]█[/color][color=#010000]████████████[/color][color=#434242]█        [/color][color=#191818]█[/color][color=#292828]█ [/color][color=#535252]█[/color][color=#222222]█[/color][color=#010000]█[/color][color=#000000]█[/color][color=#131212]█                       █[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             //
//    [color=#0c0c0c]█                        [/color][color=#626161]██[/color][color=#020101]█[/color][color=#0b0a09]████████████████████████████████[/color][color=#1d1b1b]█[/color][color=#717171]▄   [/color][color=#767676],[/color][color=#404040]█[/color][color=#0b0a0a]█[/color][color=#010000]█[/color][color=#020000]████[/color][color=#2a2929]▀[/color][color=#616161]█                        [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              //
//    [color=#0c0c0c]█                   [/color][color=#6a6a6a]▌[/color][color=#646464]█▓[/color][color=#656565]█[/color][color=#292828]█[/color][color=#3b3a3a]█[/color][color=#626161]█ [/color][color=#272525]█[/color][color=#000000]█[/color][color=#000000]████████████████████████████████ [/color][color=#737373]╓[/color][color=#2e2d2d]█[/color][color=#010000]█[/color][color=#000000]████[/color][color=#181717]█[/color][color=#4c4c4c]█   [/color][color=#666666]▓                       [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  //
//    [color=#0c0c0c]█                  [/color][color=#6d6d6d]▀[/color][color=#5e5f5f]█[/color][color=#686868]▌[/color][color=#646464]█[/color][color=#2d2b2b]█[/color][color=#000000]█[/color][color=#000000]██[/color][color=#616161]█ [/color][color=#464545]█ [/color][color=#2b2a2a]█[/color][color=#000000]█[/color][color=#000000]██████████████████████████[/color][color=#686868]▌[/color][color=#717171]└ [/color][color=#0b0909]█[/color][color=#030102]█[/color][color=#000000]████[/color][color=#2c2b2b]█[/color][color=#4d4c4c]█[/color][color=#494848]█[/color][color=#343434]█[/color][color=#212020]█[/color][color=#0d0c0c]█[/color][color=#141212]█[/color][color=#666565]█                       [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   //
//    [color=#0c0c0c]█                [/color][color=#6f6f6f]▄[/color][color=#646464]█[/color][color=#5e5e5e]█[/color][color=#232222]█[/color][color=#212020]█[/color][color=#363535]█[/color][color=#454545]█[/color][color=#010000]█[/color][color=#010000]██[/color][color=#060504]█[/color][color=#4e4d4d]█[/color][color=#696969]▌[/color][color=#6a6a6a]▌ [/color][color=#151414]█[/color][color=#020000]█[/color][color=#050000]█████████████████████████  [/color][color=#434242]██████████[/color][color=#0f0f0f]█[/color][color=#383737]█[/color][color=#656565]█[/color][color=#757575],                        [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               //
//    [color=#0c0c0c]█                [/color][color=#444444]█[/color][color=#666666]█[/color][color=#515050]█[/color][color=#010000]█[/color][color=#010000]██████████████████████████████████████[/color][color=#4c4c4c]█ █████████[/color][color=#050404]█[/color][color=#0b0909]██[/color][color=#262525]▀[/color][color=#525151]█                        [/color][color=#000000]█[/color]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            //
//    [                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   //
//                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        //
//                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


contract DV is ERC721Creator {
    constructor() ERC721Creator("Daly Ventures", "DV") {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";

contract ERC721Creator is Proxy {
    
    constructor(string memory name, string memory symbol) {
        assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = 0x80d39537860Dc3677E9345706697bf4dF6527f72;
        Address.functionDelegateCall(
            0x80d39537860Dc3677E9345706697bf4dF6527f72,
            abi.encodeWithSignature("initialize(string,string)", name, symbol)
        );
    }
        
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Returns the current implementation address.
     */
     function implementation() public view returns (address) {
        return _implementation();
    }

    function _implementation() internal override view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }    

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/Proxy.sol)

pragma solidity ^0.8.0;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overriden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overriden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly {
            r.slot := slot
        }
    }
}