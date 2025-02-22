// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library chainBeingFactory {
/* enum Animations{ STATIC, BLINK_LEFT_EYE, BLINK_RIGHT_EYE,
BLINK_BOTH_EYES,MOVE_NOSE_LEFT,MOVE_NOSE_RIGHT,
MOVE_HEAD_DOWN,MOVE_HAT_UP,MOVE_LEFT_BROW,MOVE_RIGHT_BROW,MOVE_BOTH_BROWS } */
/*
Character DNA
FFAACCIITTBBYYNNMM
 */

function charcterType(uint256 _seed) public pure returns (string memory){
   uint256 rand = uint256(keccak256(abi.encodePacked(_seed)))%1e18;
    uint256 id =((rand/1e16 )% 1e2)%10;
  
   if(id == 0) {
      return "Face0";
    }
    else if(id == 1) {
      return "Face1";

    }
    else if(id == 2){
      return "Face2";
    }
    else if(id == 3) {
     return "Face3";
    }
    else if(id == 4) {
      return "Face4";
    }
    else if(id == 5) {
     return "Face5";
    }
    else if(id == 6) {
      return "Face6";
    }
    else if(id == 7) {
     return "Face7";
    }
    else if(id == 8) {
     return "Face8";
    }
    else if(id == 9) {
     return "Face9";
    }
    else {
      return string(abi.encodePacked("ERROR"));
    }    
}
 
  function art(uint256 _seed,uint256 _frame) public pure returns (string memory) {
    uint256 characterDNA = uint256(keccak256(abi.encodePacked(_seed)))%1e18;
    uint256 colorGene=((characterDNA/1e12)%1e2)%13;   
  string[4][13] memory colors=[
  [unicode"\x1B[38;5;53m",unicode"\x1B[38;5;54m",unicode"\x1B[38;5;55m",unicode"\x1B[38;5;56m"],
  [unicode"\x1B[38;5;125m",unicode"\x1B[38;5;126m",unicode"\x1B[38;5;127m",unicode"\x1B[38;5;128m"],
  [unicode"\x1B[38;5;15m",unicode"\x1B[38;5;15m",unicode"\x1B[38;5;15m",unicode"\x1B[38;5;15m"],
  [unicode"\x1B[38;5;197m",unicode"\x1B[38;5;198m",unicode"\x1B[38;5;199m",unicode"\x1B[38;5;200m"],  
  [unicode"\x1B[38;5;202m",unicode"\x1B[38;5;203m",unicode"\x1B[38;5;204m",unicode"\x1B[38;5;205m"],
  [unicode"\x1B[38;5;209m",unicode"\x1B[38;5;210m",unicode"\x1B[38;5;211m",unicode"\x1B[38;5;212m"],
  [unicode"\x1B[38;5;15m",unicode"\x1B[38;5;15m",unicode"\x1B[38;5;15m",unicode"\x1B[38;5;15m"],
  [unicode"\x1B[38;5;33m",unicode"\x1B[38;5;69m",unicode"\x1B[38;5;105m",unicode"\x1B[38;5;141m"],
  [unicode"\x1B[38;5;34m",unicode"\x1B[38;5;70m",unicode"\x1B[38;5;106m",unicode"\x1B[38;5;142m"],
  [unicode"\x1B[38;5;15m",unicode"\x1B[38;5;15m",unicode"\x1B[38;5;15m",unicode"\x1B[38;5;15m"],
  [unicode"\x1B[38;5;51m",unicode"\x1B[38;5;87m",unicode"\x1B[38;5;123m",unicode"\x1B[38;5;159m"],  
  [unicode"\x1B[38;5;45m",unicode"\x1B[38;5;81m",unicode"\x1B[38;5;117m",unicode"\x1B[38;5;153m"],
  [unicode"\x1B[38;5;47m",unicode"\x1B[38;5;83m",unicode"\x1B[38;5;119m",unicode"\x1B[38;5;155m"] 
  ];
 

    
    string memory hair =  _chooseTops(characterDNA,_frame);
    string memory brows = _chooseEyeBrows(characterDNA,_frame);
    string memory eyes = _chooseEyes(characterDNA,_frame);
    string memory nose = _chooseNose(characterDNA,_frame); 
    string memory mouth = _chooseMouth(characterDNA);       
    return string(abi.encodePacked( colors[colorGene%13][0],hair, colors[colorGene][1],brows,colors[colorGene][2],eyes,nose,colors[colorGene][3], mouth,unicode"\x1B[0m"));
    
  }

function _chooseTops(uint256 characterDNA,uint256 _frame) internal pure returns(string memory){

   string[27] memory hairs =  [
      unicode"     _______",
      unicode"     ///////",
      unicode"     !!!!!!!",
      // unicode"     %%%%%%%",
      unicode"     ║║║║║║║",
      unicode"     ▄▄▄▄▄▄▄",
      unicode"     ███████",
      unicode"     ┌─────┐   \n"
      unicode"     │     │  \n"
      unicode"    ─┴─────┴─  ",       
      unicode"     ┌─────┐   \n"       
      unicode"     ├─────│    \n"
      unicode"    ─┴─────┴─ ",       
      unicode"     ┌▄▄▄▄▄┐  \n"       
      unicode"     ├─────┤  \n"       
      unicode"    ─┴─────┴─ ",       
      unicode"     ┌─────┐  \n"
      unicode"     ├─────┤  \n"
      unicode"    ─┴▀▀▀▀▀┴─ ",
      unicode"     ┌▄▄▄▄▄┐  \n"
      unicode"     ├─────┤  \n"
      unicode"    ─┴▀▀▀▀▀┴─ ",
      unicode"     ┌▄▄▄▄▄┐  \n"
      unicode"     ├█████┤  \n"
      unicode"    ─┴▀▀▀▀▀┴─ ",
      unicode"     ┌─────┐  \n"
      unicode"     │     │  \n"
      unicode"    ─┴▀▀▀▀▀┴─ ",
      unicode"              \n"
      unicode"     ┌─────┐  \n"
      unicode"    ─┴─────┴─ ",
      unicode"              \n"
      unicode"     ┌─────┐  \n"
      unicode"    ─┴▀▀▀▀▀┴─ ",
      unicode"              \n"
      unicode"      /███    \n"
      unicode"    ─┴▀▀▀▀▀┴─  ",
      unicode"               \n"
      unicode"      /▓▓▓    \n"
      unicode"    ─┴▀▀▀▀▀┴─  ",
      unicode"               \n"
      unicode"      ┌───┐    \n"
      unicode"   └─┴─────┴── ",
      unicode"            ,/ \n"
      unicode"      ┌───┐/'  \n"
      unicode"   └─┴─────┴── ",
      unicode"               \n"
      unicode"      .▄▄▄.    \n"
      unicode"   └─┴▀▀▀▀▀┴── ",
      unicode"            ,/ \n"
      unicode"      .▄▄▄./'  \n"
      unicode"   └─┴▀▀▀▀▀┴── ",
      unicode"               \n"
      unicode"      /ˇˇˇ    \n"
      unicode"     ┴─────┴   ",
      unicode"     ┌─────┐   \n"
      unicode"    ┌┴─────┴┐  \n"
      unicode"    └───────┘  ",
      unicode"               \n"
      unicode"     ┌─────┐   \n"
      unicode"    |░░░░░░░|  ",
      unicode"      ,.O.,    \n"
      unicode"     /»»»»»   \n"
      unicode"    /«««««««  ",
      unicode"      ,.O.,    \n"
      unicode"     /AAAAA   \n"
      unicode"    /VVVVVVV  ",
      unicode"      ,.O.,   \n"
      unicode"     /WWWWW   \n"
      unicode"    /MMMMMMM  "
    ];
    string memory beforeTop=unicode"\n\n";
    string memory afterTop=unicode"\n";
    uint256 topsGene=((characterDNA/1e8)%1e2)%27;
    uint256 animationsGene=((characterDNA/1e14)%1e2)%11;
     if (  _frame==2){
      if( animationsGene==6){
        beforeTop=unicode"\n\n\n";
        afterTop=unicode"\n";       
      }
      if(animationsGene  ==7 && topsGene>=6){
        beforeTop=unicode"\n";
        afterTop=unicode"\n\n";         
      }
     }
     return  string(abi.encodePacked(beforeTop,hairs[topsGene],afterTop));
}
  function _chooseEyeBrows(uint256 characterDNA,uint256 _frame) internal pure returns(string memory){
    uint256 id =((characterDNA/1e16 )% 1e2)%10;
     uint256 browsGene=((characterDNA/1e6)%1e2)%3;
    uint256 animationsGene=((characterDNA/1e14)%1e2)%11;
    string[3] memory brows = [
      unicode"_",
      unicode"~",
      unicode"¬"
    ];
    string memory leftBrow=brows[browsGene];
    string memory rightBrow=brows[browsGene];    
    if(_frame==2){
      if(animationsGene ==8 && browsGene ==0){
          leftBrow="-";
        }
         else if(animationsGene ==9 && browsGene ==0){
          rightBrow="-";
        }
         else if(animationsGene ==10 && browsGene ==0){
          rightBrow="-";
          leftBrow="-";
        }
    }
    
    if(id == 0) {
      return string(abi.encodePacked("    # ",leftBrow, "   ",rightBrow," #" , unicode" \n"));
    }
    else if(id == 1) {
      return string(abi.encodePacked("    ! ",leftBrow, "   ",rightBrow," !" , unicode" \n"));
    }
    else if(id == 2){
      return string(abi.encodePacked("    | ",leftBrow, "   ",rightBrow," |" , unicode" \n"));
    }
    else if(id == 3) {
      return string(abi.encodePacked("    { ",leftBrow, "   ",rightBrow," }" , unicode" \n"));
    }
    else if(id == 4) {
      return string(abi.encodePacked(unicode"    ║ ",leftBrow, "   ",rightBrow,unicode" ║" , unicode" \n"));
    }
    else if(id == 5) {
      return string(abi.encodePacked(unicode"    # ",leftBrow, "   ",rightBrow,unicode" #" , unicode" \n"));
    }
    else if(id == 6) {
      return string(abi.encodePacked(unicode"    ) ",leftBrow, "   ",rightBrow,unicode"  )" , unicode" \n"));
    }
    else if(id == 7) {
      return string(abi.encodePacked("   (# ",leftBrow, "   ",rightBrow," #)" , unicode" \n"));
    }
    else if(id == 8) {
      return string(abi.encodePacked(unicode"   |  ",leftBrow, "   ",rightBrow,unicode"  |" , unicode" \n"));
    }
    else if(id == 9) {
      return string(abi.encodePacked(unicode"   .´       `.",unicode"\n",unicode"   |  ",leftBrow, "   ",rightBrow,unicode"  |" , unicode" \n"));
    }
    else {
      return string(abi.encodePacked("ERROR"));
    }
  }

  function _chooseEyes(uint256 characterDNA,uint256 _frame) internal pure returns (string memory) {
    uint256 id =((characterDNA/1e16 )% 1e2)%10;
     uint256 eyeGene=((characterDNA/1e4)%1e2)%22;
    uint256 animationsGene=((characterDNA/1e14)%1e2)%11;
    uint256 isEyeOrGlassGene=((characterDNA/1e10)%1e2)%2;
    
    if(isEyeOrGlassGene % 2 == 0 && id != 9) {
      return _chooseGlasses(characterDNA,id);
    }
 
    string[22] memory Eyes =
      [
        unicode"0",
        unicode"9",
        unicode"o",
        unicode"O",
        unicode"p",
        unicode"P",
        unicode"q",
        unicode"°",
        unicode"Q",
        unicode"Ö",
        unicode"ö",
        unicode"ó",
        unicode"Ô",
        unicode"■",
        unicode"Ó",
        unicode"Ő",
        unicode"ő",
        unicode"○",
        unicode"╬",
        unicode"♥",
        unicode"¤",
        unicode"đ"
      ];
 
     string memory leftEye=Eyes[eyeGene ];
    string memory rightEye=Eyes[eyeGene ];
    
    if(_frame==2){
      if(animationsGene ==1){
          leftEye="-";
        }
         else if(animationsGene ==2){
          rightEye="-";
        }
         else if(animationsGene ==3){
          rightEye="-";
          leftEye="-";
        }
    }
   


    if(id == 0) {
       return
        string(
          abi.encodePacked(
            "   d| ",
            leftEye,
            "   ",
            rightEye,
            " |b",
            unicode" \n"
          )
      );
    }
    else if(id == 1) {
      return
        string(
          abi.encodePacked(
            unicode"   «│ ",
            leftEye,
            "   ",
            rightEye,
            unicode" │»",
            unicode" \n"
          )
        );
    
    }
    else if(id == 2){
       return
        string(
          abi.encodePacked(
            "    ( ",
            leftEye,
            "   ",
            rightEye,
            " )",
            unicode" \n"
          )
        );
    }
    else if(id == 3) {
      return
        string(
          abi.encodePacked(
            "   d| ",
            leftEye,
            "   ",
            rightEye,
            " |b",
            unicode" \n"
          )
      );
    }
    else if(id == 4) {
      return
      string(
        abi.encodePacked(
          unicode"   d║ ",
          leftEye,
          "   ",
          rightEye,
          unicode" ║b",
          unicode" \n"
        )
      );
    }
    else if(id == 5) {
      return
      string(
        abi.encodePacked(
          unicode"   d| ",
          leftEye,
          "   ",
          rightEye,
          unicode" |b",
          unicode" \n"
        )
      );
    }
    else if(id == 6) {
      return
      string(
        abi.encodePacked(
          unicode"   (  ",
          leftEye,
          "   ",
          rightEye,
          unicode" (",
          unicode" \n"
        )
      );
    }
    else if(id == 7) {
      return
        string(
          abi.encodePacked(
            unicode"   @| ",
            leftEye,
            "   ",
            rightEye,
            unicode" |@",
            unicode" \n"
          )
        );
    }
    else if(id == 8) {
      return
      string(
        abi.encodePacked(
          unicode" |\\|  ",
          leftEye,
          "   ",
          rightEye,
          unicode"  |/|",
          unicode" \n"
        )
      );
    }
    else if(id == 9) {
      return
      string(
        abi.encodePacked(
          unicode"   \\ (",
          leftEye,
          "   ",
          rightEye,
          unicode") /",
          unicode" \n"
        )
      );
    }
    else {
      return string(abi.encodePacked("ERROR"));
    }
    
  }

  function _chooseNose(uint256 characterDNA,uint256 _frame) internal pure returns (string memory) {
  uint256 id =((characterDNA/1e16 )% 1e2)%10;
     uint256 noseGene=((characterDNA/1e2)%1e2)%15;
    uint256 animationsGene=((characterDNA/1e14)%1e2)%11;
    
    string[15] memory noses =
      [
        unicode"<",
        unicode">",
        unicode"V",
        unicode"W",
        unicode"v",
        unicode"u",
        unicode"c",
        unicode"C",
        unicode"┴",
        unicode"L",
        unicode"Ł",
        unicode"└",
        unicode"┘",
        unicode"╚",
        unicode"╝"
    ];
    string memory leftNose=" ";
    string memory rightNose=" ";
    
    if(_frame==2 &&   id != 9){
      if(animationsGene ==5){
          leftNose="";
          rightNose="  ";
        }
         else if(animationsGene ==6){
          leftNose="  ";
          rightNose="";
        }
         
    }
    if(id == 0) {
      return string(abi.encodePacked("    (  ",leftNose,noses[noseGene ],rightNose,"  )", unicode" \n"));
    }
    else if(id == 1){
      return string(abi.encodePacked("    \\  ",leftNose,noses[noseGene ],rightNose,"  /", unicode" \n"));
    }
    else if(id == 2){
      return string(abi.encodePacked("  <(   ",leftNose,noses[noseGene ],rightNose,"   )>", unicode" \n"));
    }
    else if(id == 3) {
      return string(abi.encodePacked("    \\  ",leftNose,noses[noseGene ],rightNose,"  /", unicode" \n"));
    }
    else if(id == 4) {
      return string(abi.encodePacked(unicode"    ║  ",leftNose,noses[noseGene ],rightNose,unicode"  ║", unicode" \n"));
    }
    else if(id == 5) {
      return string(abi.encodePacked(unicode"    (  ",leftNose,noses[noseGene ],rightNose,unicode"  )", unicode" \n"));
    }
    else if(id == 6) {
      return string(abi.encodePacked(unicode"    )  ",leftNose,noses[noseGene ],rightNose,unicode"   )", unicode" \n"));
    }
    else if(id == 7){
      return string(abi.encodePacked("   (/  ",leftNose,noses[noseGene ],rightNose,"  \\)", unicode" \n"));
    }
    else if(id == 8) {
      return string(abi.encodePacked(unicode"  \\│   ",leftNose,noses[noseGene ],rightNose,unicode"   │/", unicode" \n"));
    } 
    else if(id == 9){
      return string(abi.encodePacked("    '. /V\\ ,'", unicode" \n"));
    }
    else {
      return string(abi.encodePacked("ERROR"));
    }

  }

  
  function _chooseMouth(uint256 characterDNA) internal pure returns (string memory) {
   uint256 id =((characterDNA/1e16 )% 1e2)%10;
     uint256 mouthGene=((characterDNA/1e0)%1e2)%5;
  
    string[5] memory mouths =
      [
      unicode"---",
      unicode"___",
      unicode"===",
      unicode"~~~",
      unicode"═══"
      ];

    if(id == 0){
      return string(abi.encodePacked("     ) ",mouths[mouthGene ]," (",unicode" \n",unicode"     (_____)"));
    }
    else if (id == 1){
      return string(abi.encodePacked(unicode"     ├ ",mouths[mouthGene ],unicode" ┤",unicode"  \n",unicode"      \'───\'"));
    }
    else if(id == 2) {
      return string(abi.encodePacked("    \\  ",mouths[mouthGene ],"  /",unicode" \n",unicode"      \\ˍˍˍ/"));
    }
    else if(id == 3){
      return string(abi.encodePacked("     { ",mouths[mouthGene ]," }",unicode" \n",unicode"      └~~~┘"));
    }
    else if(id == 4){
      return string(abi.encodePacked(unicode"    ╚╗ ",mouths[mouthGene ],unicode" ╔╝",unicode" \n",unicode"     ╚═════╝"));
    }
    else if(id == 5){
      return string(abi.encodePacked(unicode"     |\\",mouths[mouthGene ],unicode"/|",unicode" \n",unicode"      \\_‿_/"));
    }
    else if(id == 6){
      return string(abi.encodePacked(unicode"   (   ",mouths[mouthGene ],unicode"  (",unicode" \n",unicode"    `─ ─ ─ ─´"));
    }
    else if(id == 7){
      return string(abi.encodePacked(unicode"   (|  ",mouths[mouthGene ],unicode"  |)",unicode" \n",unicode"     `─────´"));
    }
    else if(id == 8){
      return string(abi.encodePacked(unicode"    \\  ",mouths[mouthGene ],unicode"  /",unicode" \n",unicode"      \\___/"));
    }
    else if (id == 9){
      return string(abi.encodePacked(unicode"     \\ ",mouths[mouthGene ],unicode" /",unicode"  \n",unicode"      '---'"));
    }
    else {
      return string(abi.encodePacked("ERROR"));
    }
    
  }


  function _chooseGlasses(uint256 characterDNA,uint256 id) internal pure returns(string memory) {
      
     uint256 glassesGene=((characterDNA/1e4)%1e2)%16;
     
   
    
    string[16] memory glasses = [
      unicode"-O---O-",
      unicode"-O-_-O-",
      unicode"-┴┴-┴┴-",
      unicode"-┬┬-┬┬-",
      unicode"-▄---▄-",
      unicode"-▄-_-▄-",
      unicode"-▀---▀-",
      unicode"-▀-_-▀-",
      unicode"-█---█-",
      unicode"-█-_-█-",
      unicode"-▓---▓-",
      unicode"-▓-_-▓-",
      unicode"-▒---▒-",
      unicode"-▒-_-▒-",
      unicode"-░---░-",
      unicode"-░-_-░-"
    ];

  string memory glass = glasses[glassesGene];

    if(id == 0) {
       return
        string(
          abi.encodePacked(
            "   d|",
            glass,
            "|b",
            unicode" \n"
          )
      );
    }
    else if(id == 1) {
      return
        string(
          abi.encodePacked(
            unicode"   «│",
            glass,
            unicode"│»",
            unicode" \n"
          )
        );
    
    }
    else if(id == 2){
       return
        string(
          abi.encodePacked(
            "    (",
            glass,
            ")",
            unicode" \n"
          )
        );
    }else if(id == 3) {
      return
        string(
          abi.encodePacked(
            "   d|",
            glass,
            "|b",
            unicode" \n"
          )
      );
    }else if(id == 4) {
      return
      string(
        abi.encodePacked(
          unicode"   d║",
          glass,
          unicode"║b",
          unicode" \n"
        )
      );
    }else if(id == 5) {
      return
      string(
        abi.encodePacked(
          unicode"   d|",
          glass,
          unicode"|b",
          unicode" \n"
        )
      );
    }else if(id == 6) {
      return
      string(
        abi.encodePacked(
          unicode"   ( ",
          glass,
          unicode"(",
          unicode" \n"
        )
      );
    }
    else if(id == 7) {
      return
        string(
          abi.encodePacked(
            unicode"  @| ",
            glass,
            unicode" |@",
            unicode" \n"
          )
        );
    }
    else if(id == 8) {
      return
      string(
        abi.encodePacked(
          unicode" |\\| ",
          glass,
          unicode" |/|",
          unicode" \n"
        )
      );
    }
    else if(id == 9) {
      return
      string(
        abi.encodePacked(
          unicode" \\  ",
          glass,
          unicode"  /",
          unicode" \n"
        )
      );
    }
    else {
      return string(abi.encodePacked("ERROR"));
    }

  } 
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "./ChainBeing/chainBeingFactory.sol";

contract Test {
    function testingDraw(uint256 _seed, uint256 _frame)
        public
        pure
        returns (string memory)
    {
        return chainBeingFactory.art(_seed, _frame);
    }

    function testRand(uint256 _seed) public pure returns(uint256) {
        uint256 rand = uint256(keccak256(abi.encodePacked(_seed))); // %1e18;
        return rand;
    }
}