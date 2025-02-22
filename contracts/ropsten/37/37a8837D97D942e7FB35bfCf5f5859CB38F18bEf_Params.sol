// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;
pragma experimental ABIEncoderV2;
import {G} from "G.sol";
import {Admin} from "Admin.sol";

contract Params {
    Admin public admin;
    
    // G.G1Point[] private hs;//
    // G.G2Point private alpha;
    // G.G2Point[] private beta;
    // G.G2Point[] private opk;



    //modifier onlyOwner {
     //   require(msg.sender == 0x5D0D81228C32f2E5b28D6Ea0791245650E02C0Cc || msg.sender == 0x5eC89be5D79ca079Bb66a1aC9B3E6DF65bb4672A || msg.sender == 0x74C97b23470E9FBE71354324eC9655B422aDa544 || msg.sender == 0xF119F8e23bA523A260c6Ea9e9262c84876f2B2b0);
    //    _;
   // }

    function set_admin(address addr) public {
    admin = Admin(addr);
  }

  
    // function set_params(G.G1Point[] memory _hs, G.G2Point memory _alpha, G.G2Point[] memory _beta, G.G2Point[] memory _opk) public onlyOwner {
    //     uint i = 0;
    //     delete hs;
    //     delete beta;
    //     delete opk;

    //     for(i=0; i < _hs.length; i++) {
            
    //         hs.push(_hs[i]);
    //     }

    //     alpha = _alpha;


    //     for(i=0; i < _beta.length; i++) {
    //         beta.push(_beta[i]);
    //     }

    //     for(i=0; i < _opk.length; i++) {
    //         opk.push(_opk[i]);
    //     }

    // }
        
    // function get_hs() public view returns (G.G1Point[] memory) {
    //     return hs;
    // }

    // function get_alpha() public view returns (G.G2Point memory) {
    //     return alpha;
    // }
    
    // function get_beta() public view returns (G.G2Point[] memory) {
    //     return beta;
    // }
    
    // function get_opk() public view returns (G.G2Point[] memory) {
    //     return opk;
    // }


// ==================NIkhil added code starts below,,,, agar kabhi error aya toh isme hi dunde===================================

mapping(uint256 => G.G1Point[]) private hsmapping; 
mapping(uint256 => G.G2Point) private alphamapping; 
mapping(uint256 => G.G2Point[]) private betamapping; 
mapping(uint256 => G.G2Point[]) private opkmapping; 
function set_params(uint256 serviceID, G.G1Point[] memory _hs, G.G2Point memory _alpha, G.G2Point[] memory _beta,G.G2Point[] memory _opk) public { //, G.G2Point[] memory _opk
        delete hsmapping[serviceID];
        delete alphamapping[serviceID];
        delete betamapping[serviceID];
        delete opkmapping[serviceID];
        for(uint256 i=0; i < _hs.length; i++) {
            hsmapping[serviceID].push(_hs[i]);   
        }
        alphamapping[serviceID] = _alpha;

        for(uint256 h=0; h < _beta.length; h++) {
            betamapping[serviceID].push(_beta[h]);
        }

        for(uint256 l=0;l< _opk.length; l++) {
            opkmapping[serviceID].push(_opk[l]);
        }
        
    }



function get_opk(uint256 serviceID) public view returns (G.G2Point[] memory) {
    return opkmapping[serviceID];
}

function get_hs(uint256 serviceID) public view returns (G.G1Point[] memory) {
    return hsmapping[serviceID];
}

function get_alpha(uint256 serviceID) public view returns (G.G2Point memory) {
    return alphamapping[serviceID];
}

function get_beta(uint256 serviceID) public view returns (G.G2Point[] memory) {
    return betamapping[serviceID];
}



function get_hs(uint256 serviceID,uint i) public view returns (G.G1Point memory) {
    return hsmapping[serviceID][i];
}

function get_beta(uint256 serviceID,uint i) public view returns (G.G2Point memory) {
    return betamapping[serviceID][i];
}

function get_opk(uint256 serviceID,uint i) public view returns (G.G2Point memory) {
  return opkmapping[serviceID][i];
}

// function get_opk(uint256 serviceID,uint i) public view returns (G.G2Point memory) {
//   return opkmapping[serviceID][i];
// }

//==========================Nikhil's code end here================================

  mapping(uint256 => G.G1Point) private ttpKeys;
  mapping(uint256 => uint256[]) private include_indexes;
  mapping(uint256 => G.G1Point[]) private ttp_params;



//now from admin, only include index to add here.

  // function admin_ttp(uint256 ttp_id, G.G1Point memory ttp_pk, uint256[] memory indexes, G.G1Point[] memory _hs) public onlyOwner {
  //   ttpKeys[ttp_id] = ttp_pk;
  //   include_indexes[ttp_id] = indexes;
  //   uint256 i = 0;
  //   for (i=0; i< _hs.length; i++) {
  //       ttp_params[ttp_id].push(_hs[i]);
  //   }
  // }
//   taking from admin

  function get_ttpKeys(uint256 ttp_id) public view returns(G.G1Point memory) {
    // return ttpKeys[ttp_id];
    return admin.get_ttpKeys(ttp_id);
  }

  function get_include_indexes(uint256 ttp_id, uint256 service_id) public view returns(uint256[] memory) {
    return admin.return_indexing(ttp_id, service_id);
  }

//   taking from admin
  function get_ttp_params(uint256 ttp_id) public view returns(G.G1Point[] memory) {
    return admin.get_ttp_params(ttp_id);
  }

}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.19 <0.9.0;

import {BN256G2} from "BN256G2.sol";

library G {

   	// p = p(u) = 36u^4 + 36u^3 + 24u^2 + 6u + 1
    uint256 internal constant FIELD_ORDER = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;

    // Number of elements in the field (often called `q`)
    // n = n(u) = 36u^4 + 36u^3 + 18u^2 + 6u + 1
    uint256 internal constant GEN_ORDER = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;

    uint256 internal constant CURVE_B = 3;

    // a = (p+1) / 4
    uint256 internal constant CURVE_A = 0xc19139cb84c680a6e14116da060561765e05aa45a1c72a34f082305b61f3f52;

	struct G1Point {
		uint256 X;
		uint256 Y;
	}

	// Encoding of field elements is: X[0] * z + X[1]
	struct G2Point {
		uint256[2] X;
		uint256[2] Y;
	}

	// (P+1) / 4
	function A() pure internal returns (uint256) {
		return CURVE_A;
	}

	function P() pure internal returns (uint256) {
		return FIELD_ORDER;
	}

	function N() pure internal returns (uint256) {
		return GEN_ORDER;
	}

	/// @return the generator of G1
	function P1() pure internal returns (G1Point memory) {
		return G1Point(1, 2);
	}

	function _modInv(uint256 a, uint256 n) internal view returns (uint256 result) {
        bool success;
        assembly {
            let freemem := mload(0x40)
            mstore(freemem, 0x20)
            mstore(add(freemem,0x20), 0x20)
            mstore(add(freemem,0x40), 0x20)
            mstore(add(freemem,0x60), a)
            mstore(add(freemem,0x80), sub(n, 2))
            mstore(add(freemem,0xA0), n)
            success := staticcall(sub(gas(), 2000), 5, freemem, 0xC0, freemem, 0x20)
            result := mload(freemem)
        }
        require(success);
    }

	function do_ecdsa_verify(G1Point memory commit, G1Point memory pk, uint256[2] memory sign) view internal returns(bool){
	    bytes32 hash_digest = G1_to_binary256(commit);
	    uint256 s1 = _modInv(sign[1], N());
	    uint256 x1 = mulmod(uint256(hash_digest), s1, N());
	    uint256 x2 = mulmod(sign[0], s1, N());
	    G1Point memory tmp = g1mul(P1(), x1);
	    tmp = g1add(tmp, g1mul(pk, x2));
	    return tmp.X == sign[0];
  }

  function HashToPoint(uint256 s)
        internal view returns (G1Point memory)
    {
        uint256 beta = 0;
        uint256 y = 0;

        // XXX: Gen Order (n) or Field Order (p) ?
        uint256 x = s % GEN_ORDER;

        while( true ) {
            (beta, y) = FindYforX(x);

            // y^2 == beta
            if( beta == mulmod(y, y, FIELD_ORDER) ) {
                return G1Point(x, y);
            }

            x = addmod(x, 1, FIELD_ORDER);
        }
    }

    /**
    * Given X, find Y
    *
    *   where y = sqrt(x^3 + b)
    *
    * Returns: (x^3 + b), y
    */
    function FindYforX(uint256 x)
        internal view returns (uint256, uint256)
    {
        // beta = (x^3 + b) % p
        uint256 beta = addmod(mulmod(mulmod(x, x, FIELD_ORDER), x, FIELD_ORDER), CURVE_B, FIELD_ORDER);

        // y^2 = x^3 + b
        // this acts like: y = sqrt(beta)
        uint256 y = expMod(beta, CURVE_A, FIELD_ORDER);

        return (beta, y);
    }


    // a - b = c;
    function submod(uint a, uint b) internal pure returns (uint){
        uint a_nn;
        if(a>b) {
            a_nn = a;
        } else {
            a_nn = a+GEN_ORDER;
        }
        return addmod(a_nn - b, 0, GEN_ORDER);
    }


    function expMod(uint256 _base, uint256 _exponent, uint256 _modulus)
        internal view returns (uint256 retval)
    {
        bool success;
        uint256[1] memory output;
        uint[6] memory input;
        input[0] = 0x20;        // baseLen = new(big.Int).SetBytes(getData(input, 0, 32))
        input[1] = 0x20;        // expLen  = new(big.Int).SetBytes(getData(input, 32, 32))
        input[2] = 0x20;        // modLen  = new(big.Int).SetBytes(getData(input, 64, 32))
        input[3] = _base;
        input[4] = _exponent;
        input[5] = _modulus;
        assembly{
            success := staticcall(sub(gas(), 2000), 5, input, 0xc0, output, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
        return output[0];
    }


	/// @return the generator of G2
	function P2() pure internal returns (G2Point memory) {
		return G2Point(
			[11559732032986387107991004021392285783925812861821192530917403151452391805634,
			 10857046999023057135944570762232829481370756359578518086990519993285655852781],
			[4082367875863433681332203403145435568316851327593401208105741076214120093531,
			 8495653923123431417604973247489272438418190587263600148770280649306958101930]
		);
	}

	/// @return the negation of p, i.e. p.add(p.negate()) should be zero.
	function g1neg(G1Point memory p) pure internal returns (G1Point memory) {
		// The prime q in the base field F_q for G1
		uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
		if (p.X == 0 && p.Y == 0)
			return G1Point(0, 0);
		return G1Point(p.X, q - (p.Y % q));
	}

	function isinf(G1Point memory p) pure internal returns (bool) {
		if (p.X == 0 && p.Y == 0) {
			return true;
		}
		return false;
	}

	function g1add(G1Point memory p1, G1Point memory p2) view internal returns (G1Point memory r) {
		uint[4] memory input;
		input[0] = p1.X;
		input[1] = p1.Y;
		input[2] = p2.X;
		input[3] = p2.Y;
		bool success;
		assembly {
			success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
			// Use "invalid" to make gas estimation work
			switch success case 0 { invalid() }
		}
		require(success);
	}

	function g2add(G2Point memory p1, G2Point memory p2) view internal returns (G2Point memory r) {
		(r.X[1], r.X[0], r.Y[1], r.Y[0]) = BN256G2.ECTwistAdd(p1.X[1], p1.X[0], p1.Y[1], p1.Y[0], p2.X[1], p2.X[0], p2.Y[1], p2.Y[0]);
		return r;
	}

	function g1mul(G1Point memory p, uint s) view internal returns (G1Point memory r) {
		uint[3] memory input;
		input[0] = p.X;
		input[1] = p.Y;
		input[2] = s;
		bool success;
		assembly {
			success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
			// Use "invalid" to make gas estimation work
			switch success case 0 { invalid() }
		}
		require (success);
	}


	/// @return the result of computing the pairing check
	/// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
	/// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
	/// return true.
	function pairing(G1Point[] memory p1, G2Point[] memory p2) view internal returns (bool) {
		require(p1.length == p2.length);
		uint elements = p1.length;
		uint inputSize = elements * 6;
		uint[] memory input = new uint[](inputSize);
		for (uint i = 0; i < elements; i++)
		{
			input[i * 6 + 0] = p1[i].X;
			input[i * 6 + 1] = p1[i].Y;
			input[i * 6 + 2] = p2[i].X[0];
			input[i * 6 + 3] = p2[i].X[1];
			input[i * 6 + 4] = p2[i].Y[0];
			input[i * 6 + 5] = p2[i].Y[1];
		}
		uint[1] memory out;
		bool success;
		assembly {
			success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
			// Use "invalid" to make gas estimation work
			switch success case 0 { invalid() }
		}
		require(success);
		return out[0] != 0;
	}
	
	function G1_to_binary256(G1Point memory point) internal pure returns (bytes32) {
      bytes32 X = bytes32(point.X);
      bytes32 Y = bytes32(point.Y);
      bytes memory result = new bytes(64);
      uint i = 0;
      for (i=0; i< 32 ; i++) {
          result[i] = X[i];
      }
      for (i=0; i< 32 ; i++) {
          result[32 + i] = Y[i];
      }
     return sha256(result);
  }

  function G2_to_binary256(G2Point memory point) internal pure returns (bytes32) {
      
      bytes memory result = new bytes(128);
      bytes32 X = bytes32(point.X[1]);
      uint i = 0;
      for (i=0; i< 32 ; i++) {
          result[i] = X[i];
      }
      X = bytes32(point.X[0]);
      for (i=0; i< 32 ; i++) {
          result[32 + i] = X[i];
      }
      X = bytes32(point.Y[1]);
      for (i=0; i< 32 ; i++) {
          result[64 + i] = X[i];
      }
      X = bytes32(point.Y[0]);
      for (i=0; i< 32 ; i++) {
          result[96 + i] = X[i];
      }
      return sha256(result);
  }

  function EC_to_binary256(uint256 _X, uint256 _Y) internal pure returns(bytes32) {
      bytes32 X = bytes32(_X);
      bytes32 Y = bytes32(_Y);
      bytes memory result = new bytes(64);
      uint i = 0;
      for (i=0; i< 32 ; i++) {
          result[i] = X[i];
      }
      for (i=0; i< 32 ; i++) {
          result[32 + i] = Y[i];
      }
     return sha256(result);
  }
  
  function ec_sum(G2Point[] memory points) internal view returns(G2Point memory) {
  G2Point memory result = G2Point([uint256(0),0],[uint256(0),0]);
  uint i = 0;
  for(i=0; i<points.length; i++) 
  {
    result = g2add(result, points[i]);
  }
  return result;
}
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.19 <0.9.0;


library BN256G2 {
    uint256 internal constant FIELD_MODULUS = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;
    uint256 internal constant TWISTBX = 0x2b149d40ceb8aaae81be18991be06ac3b5b4c5e559dbefa33267e6dc24a138e5;
    uint256 internal constant TWISTBY = 0x9713b03af0fed4cd2cafadeed8fdf4a74fa084e52d1852e4a2bd0685c315d2;
    uint internal constant PTXX = 0;
    uint internal constant PTXY = 1;
    uint internal constant PTYX = 2;
    uint internal constant PTYY = 3;
    uint internal constant PTZX = 4;
    uint internal constant PTZY = 5;

    /**
     * @notice Add two twist points
     * @param pt1xx Coefficient 1 of x on point 1
     * @param pt1xy Coefficient 2 of x on point 1
     * @param pt1yx Coefficient 1 of y on point 1
     * @param pt1yy Coefficient 2 of y on point 1
     * @param pt2xx Coefficient 1 of x on point 2
     * @param pt2xy Coefficient 2 of x on point 2
     * @param pt2yx Coefficient 1 of y on point 2
     * @param pt2yy Coefficient 2 of y on point 2
     * @return (pt3xx, pt3xy, pt3yx, pt3yy)
     */
    function ECTwistAdd(
        uint256 pt1xx, uint256 pt1xy,
        uint256 pt1yx, uint256 pt1yy,
        uint256 pt2xx, uint256 pt2xy,
        uint256 pt2yx, uint256 pt2yy
    ) public view returns (
        uint256, uint256,
        uint256, uint256
    ) {
        if (
            pt1xx == 0 && pt1xy == 0 &&
            pt1yx == 0 && pt1yy == 0
        ) {
            if (!(
                pt2xx == 0 && pt2xy == 0 &&
                pt2yx == 0 && pt2yy == 0
            )) {
                assert(_isOnCurve(
                    pt2xx, pt2xy,
                    pt2yx, pt2yy
                ));
            }
            return (
                pt2xx, pt2xy,
                pt2yx, pt2yy
            );
        } else if (
            pt2xx == 0 && pt2xy == 0 &&
            pt2yx == 0 && pt2yy == 0
        ) {
            assert(_isOnCurve(
                pt1xx, pt1xy,
                pt1yx, pt1yy
            ));
            return (
                pt1xx, pt1xy,
                pt1yx, pt1yy
            );
        }

        assert(_isOnCurve(
            pt1xx, pt1xy,
            pt1yx, pt1yy
        ));
        assert(_isOnCurve(
            pt2xx, pt2xy,
            pt2yx, pt2yy
        ));

        uint256[6] memory pt3 = _ECTwistAddJacobian(
            pt1xx, pt1xy,
            pt1yx, pt1yy,
            1,     0,
            pt2xx, pt2xy,
            pt2yx, pt2yy,
            1,     0
        );

        return _fromJacobian(
            pt3[PTXX], pt3[PTXY],
            pt3[PTYX], pt3[PTYY],
            pt3[PTZX], pt3[PTZY]
        );
    }

    /**
     * @notice Get the field modulus
     * @return The field modulus
     */

    function submod(uint256 a, uint256 b, uint256 n) internal pure returns (uint256) {
        return addmod(a, n - b, n);
    }

    function _FQ2Mul(
        uint256 xx, uint256 xy,
        uint256 yx, uint256 yy
    ) internal pure returns (uint256, uint256) {
        return (
            submod(mulmod(xx, yx, FIELD_MODULUS), mulmod(xy, yy, FIELD_MODULUS), FIELD_MODULUS),
            addmod(mulmod(xx, yy, FIELD_MODULUS), mulmod(xy, yx, FIELD_MODULUS), FIELD_MODULUS)
        );
    }

    function _FQ2Muc(
        uint256 xx, uint256 xy,
        uint256 c
    ) internal pure returns (uint256, uint256) {
        return (
            mulmod(xx, c, FIELD_MODULUS),
            mulmod(xy, c, FIELD_MODULUS)
        );
    }

    function _FQ2Sub(
        uint256 xx, uint256 xy,
        uint256 yx, uint256 yy
    ) internal pure returns (uint256 rx, uint256 ry) {
        return (
            submod(xx, yx, FIELD_MODULUS),
            submod(xy, yy, FIELD_MODULUS)
        );
    }

    function _FQ2Inv(uint256 x, uint256 y) internal view returns (uint256, uint256) {
        uint256 inv = _modInv(addmod(mulmod(y, y, FIELD_MODULUS), mulmod(x, x, FIELD_MODULUS), FIELD_MODULUS), FIELD_MODULUS);
        return (
            mulmod(x, inv, FIELD_MODULUS),
            FIELD_MODULUS - mulmod(y, inv, FIELD_MODULUS)
        );
    }

    function _isOnCurve(
        uint256 xx, uint256 xy,
        uint256 yx, uint256 yy
    ) internal pure returns (bool) {
        uint256 yyx;
        uint256 yyy;
        uint256 xxxx;
        uint256 xxxy;
        (yyx, yyy) = _FQ2Mul(yx, yy, yx, yy);
        (xxxx, xxxy) = _FQ2Mul(xx, xy, xx, xy);
        (xxxx, xxxy) = _FQ2Mul(xxxx, xxxy, xx, xy);
        (yyx, yyy) = _FQ2Sub(yyx, yyy, xxxx, xxxy);
        (yyx, yyy) = _FQ2Sub(yyx, yyy, TWISTBX, TWISTBY);
        return yyx == 0 && yyy == 0;
    }

    function _modInv(uint256 a, uint256 n) internal view returns (uint256 result) {
        bool success;
        assembly {
            let freemem := mload(0x40)
            mstore(freemem, 0x20)
            mstore(add(freemem,0x20), 0x20)
            mstore(add(freemem,0x40), 0x20)
            mstore(add(freemem,0x60), a)
            mstore(add(freemem,0x80), sub(n, 2))
            mstore(add(freemem,0xA0), n)
            success := staticcall(sub(gas(), 2000), 5, freemem, 0xC0, freemem, 0x20)
            result := mload(freemem)
        }
        require(success);
    }

    function _fromJacobian(
        uint256 pt1xx, uint256 pt1xy,
        uint256 pt1yx, uint256 pt1yy,
        uint256 pt1zx, uint256 pt1zy
    ) internal view returns (
        uint256 pt2xx, uint256 pt2xy,
        uint256 pt2yx, uint256 pt2yy
    ) {
        uint256 invzx;
        uint256 invzy;
        (invzx, invzy) = _FQ2Inv(pt1zx, pt1zy);
        (pt2xx, pt2xy) = _FQ2Mul(pt1xx, pt1xy, invzx, invzy);
        (pt2yx, pt2yy) = _FQ2Mul(pt1yx, pt1yy, invzx, invzy);
    }

    function _ECTwistAddJacobian(
        uint256 pt1xx, uint256 pt1xy,
        uint256 pt1yx, uint256 pt1yy,
        uint256 pt1zx, uint256 pt1zy,
        uint256 pt2xx, uint256 pt2xy,
        uint256 pt2yx, uint256 pt2yy,
        uint256 pt2zx, uint256 pt2zy) internal pure returns (uint256[6] memory pt3) {
            if (pt1zx == 0 && pt1zy == 0) {
                (
                    pt3[PTXX], pt3[PTXY],
                    pt3[PTYX], pt3[PTYY],
                    pt3[PTZX], pt3[PTZY]
                ) = (
                    pt2xx, pt2xy,
                    pt2yx, pt2yy,
                    pt2zx, pt2zy
                );
                return pt3;
            } else if (pt2zx == 0 && pt2zy == 0) {
                (
                    pt3[PTXX], pt3[PTXY],
                    pt3[PTYX], pt3[PTYY],
                    pt3[PTZX], pt3[PTZY]
                ) = (
                    pt1xx, pt1xy,
                    pt1yx, pt1yy,
                    pt1zx, pt1zy
                );
                return pt3;
            }

            (pt2yx,     pt2yy)     = _FQ2Mul(pt2yx, pt2yy, pt1zx, pt1zy); // U1 = y2 * z1
            (pt3[PTYX], pt3[PTYY]) = _FQ2Mul(pt1yx, pt1yy, pt2zx, pt2zy); // U2 = y1 * z2
            (pt2xx,     pt2xy)     = _FQ2Mul(pt2xx, pt2xy, pt1zx, pt1zy); // V1 = x2 * z1
            (pt3[PTZX], pt3[PTZY]) = _FQ2Mul(pt1xx, pt1xy, pt2zx, pt2zy); // V2 = x1 * z2

            if (pt2xx == pt3[PTZX] && pt2xy == pt3[PTZY]) {
                if (pt2yx == pt3[PTYX] && pt2yy == pt3[PTYY]) {
                    (
                        pt3[PTXX], pt3[PTXY],
                        pt3[PTYX], pt3[PTYY],
                        pt3[PTZX], pt3[PTZY]
                    ) = _ECTwistDoubleJacobian(pt1xx, pt1xy, pt1yx, pt1yy, pt1zx, pt1zy);
                    return pt3;
                }
                (
                    pt3[PTXX], pt3[PTXY],
                    pt3[PTYX], pt3[PTYY],
                    pt3[PTZX], pt3[PTZY]
                ) = (
                    1, 0,
                    1, 0,
                    0, 0
                );
                return pt3;
            }

            (pt2zx,     pt2zy)     = _FQ2Mul(pt1zx, pt1zy, pt2zx,     pt2zy);     // W = z1 * z2
            (pt1xx,     pt1xy)     = _FQ2Sub(pt2yx, pt2yy, pt3[PTYX], pt3[PTYY]); // U = U1 - U2
            (pt1yx,     pt1yy)     = _FQ2Sub(pt2xx, pt2xy, pt3[PTZX], pt3[PTZY]); // V = V1 - V2
            (pt1zx,     pt1zy)     = _FQ2Mul(pt1yx, pt1yy, pt1yx,     pt1yy);     // V_squared = V * V
            (pt2yx,     pt2yy)     = _FQ2Mul(pt1zx, pt1zy, pt3[PTZX], pt3[PTZY]); // V_squared_times_V2 = V_squared * V2
            (pt1zx,     pt1zy)     = _FQ2Mul(pt1zx, pt1zy, pt1yx,     pt1yy);     // V_cubed = V * V_squared
            (pt3[PTZX], pt3[PTZY]) = _FQ2Mul(pt1zx, pt1zy, pt2zx,     pt2zy);     // newz = V_cubed * W
            (pt2xx,     pt2xy)     = _FQ2Mul(pt1xx, pt1xy, pt1xx,     pt1xy);     // U * U
            (pt2xx,     pt2xy)     = _FQ2Mul(pt2xx, pt2xy, pt2zx,     pt2zy);     // U * U * W
            (pt2xx,     pt2xy)     = _FQ2Sub(pt2xx, pt2xy, pt1zx,     pt1zy);     // U * U * W - V_cubed
            (pt2zx,     pt2zy)     = _FQ2Muc(pt2yx, pt2yy, 2);                    // 2 * V_squared_times_V2
            (pt2xx,     pt2xy)     = _FQ2Sub(pt2xx, pt2xy, pt2zx,     pt2zy);     // A = U * U * W - V_cubed - 2 * V_squared_times_V2
            (pt3[PTXX], pt3[PTXY]) = _FQ2Mul(pt1yx, pt1yy, pt2xx,     pt2xy);     // newx = V * A
            (pt1yx,     pt1yy)     = _FQ2Sub(pt2yx, pt2yy, pt2xx,     pt2xy);     // V_squared_times_V2 - A
            (pt1yx,     pt1yy)     = _FQ2Mul(pt1xx, pt1xy, pt1yx,     pt1yy);     // U * (V_squared_times_V2 - A)
            (pt1xx,     pt1xy)     = _FQ2Mul(pt1zx, pt1zy, pt3[PTYX], pt3[PTYY]); // V_cubed * U2
            (pt3[PTYX], pt3[PTYY]) = _FQ2Sub(pt1yx, pt1yy, pt1xx,     pt1xy);     // newy = U * (V_squared_times_V2 - A) - V_cubed * U2
    }

    function _ECTwistDoubleJacobian(
        uint256 pt1xx, uint256 pt1xy,
        uint256 pt1yx, uint256 pt1yy,
        uint256 pt1zx, uint256 pt1zy
    ) internal pure returns (
        uint256 pt2xx, uint256 pt2xy,
        uint256 pt2yx, uint256 pt2yy,
        uint256 pt2zx, uint256 pt2zy
    ) {
        (pt2xx, pt2xy) = _FQ2Muc(pt1xx, pt1xy, 3);            // 3 * x
        (pt2xx, pt2xy) = _FQ2Mul(pt2xx, pt2xy, pt1xx, pt1xy); // W = 3 * x * x
        (pt1zx, pt1zy) = _FQ2Mul(pt1yx, pt1yy, pt1zx, pt1zy); // S = y * z
        (pt2yx, pt2yy) = _FQ2Mul(pt1xx, pt1xy, pt1yx, pt1yy); // x * y
        (pt2yx, pt2yy) = _FQ2Mul(pt2yx, pt2yy, pt1zx, pt1zy); // B = x * y * S
        (pt1xx, pt1xy) = _FQ2Mul(pt2xx, pt2xy, pt2xx, pt2xy); // W * W
        (pt2zx, pt2zy) = _FQ2Muc(pt2yx, pt2yy, 8);            // 8 * B
        (pt1xx, pt1xy) = _FQ2Sub(pt1xx, pt1xy, pt2zx, pt2zy); // H = W * W - 8 * B
        (pt2zx, pt2zy) = _FQ2Mul(pt1zx, pt1zy, pt1zx, pt1zy); // S_squared = S * S
        (pt2yx, pt2yy) = _FQ2Muc(pt2yx, pt2yy, 4);            // 4 * B
        (pt2yx, pt2yy) = _FQ2Sub(pt2yx, pt2yy, pt1xx, pt1xy); // 4 * B - H
        (pt2yx, pt2yy) = _FQ2Mul(pt2yx, pt2yy, pt2xx, pt2xy); // W * (4 * B - H)
        (pt2xx, pt2xy) = _FQ2Muc(pt1yx, pt1yy, 8);            // 8 * y
        (pt2xx, pt2xy) = _FQ2Mul(pt2xx, pt2xy, pt1yx, pt1yy); // 8 * y * y
        (pt2xx, pt2xy) = _FQ2Mul(pt2xx, pt2xy, pt2zx, pt2zy); // 8 * y * y * S_squared
        (pt2yx, pt2yy) = _FQ2Sub(pt2yx, pt2yy, pt2xx, pt2xy); // newy = W * (4 * B - H) - 8 * y * y * S_squared
        (pt2xx, pt2xy) = _FQ2Muc(pt1xx, pt1xy, 2);            // 2 * H
        (pt2xx, pt2xy) = _FQ2Mul(pt2xx, pt2xy, pt1zx, pt1zy); // newx = 2 * H * S
        (pt2zx, pt2zy) = _FQ2Mul(pt1zx, pt1zy, pt2zx, pt2zy); // S * S_squared
        (pt2zx, pt2zy) = _FQ2Muc(pt2zx, pt2zy, 8);            // newz = 8 * S * S_squared
    }
}

// SPDX-License-Identifier: MIT
// Solidity program to demonstrate
// the above approach

pragma solidity >=0.5.0 <0.9.0;
import {G} from "G.sol";
pragma experimental ABIEncoderV2;
contract Admin{
    

// G.G1Point[] private hs;//
// G.G2Point private alpha;
// G.G2Point[] private beta;


uint[] serviceIDList;
string[] serviceNameList; 
mapping(uint256 => uint256) totalOpener;
mapping(uint256 => uint256) thresholdOpener;
mapping(uint256 => uint256) totalValidator;
mapping(uint256 => uint256) thresholdValidator;

//newlyadded

    mapping(uint => mapping(uint => uint[])) includeIndex;
    mapping(uint => mapping(uint => uint[])) TTPSequence;

    // function indexing(uint TTPId, uint ServiceId,uint[] memory data) public {
    //   includeIndex[TTPId][ServiceId] = data;
    // //   return true;
    // }
    
    // function retunindexing(uint TTPId, uint ServiceId) public view returns(uint[] memory success) {
    //   return includeIndex[TTPId][ServiceId];
      
    // }

    function mappingSequence(uint serviceID, uint sequence ,uint[] memory data) public {
      TTPSequence[serviceID][sequence] = data;
    //   return true;
    }
    
    function returnmappingSequence(uint serviceID, uint sequence) public view returns(uint[] memory success) {
      return TTPSequence[serviceID][sequence];
    }


mapping(uint256 => G.G1Point) private ttpKeys;
mapping(uint256 => G.G1Point[]) private ttp_params;


  function add_ttp(uint256 ttp_id,G.G1Point memory ttp_pk, G.G1Point[] memory  _hs) public { //, G.G1Point memory ttp_pk, G.G1Point[] memory  _hs
      ttpKeys[ttp_id] = ttp_pk;
      uint256 len = _hs.length;
      delete ttp_params[ttp_id];  
      
      for (uint256 i=0; i< _hs.length; i++) {
              ttp_params[ttp_id].push( _hs[i]);
          }
  }

  function get_ttpKeys(uint256 ttp_id) public view returns(G.G1Point memory) {
      return ttpKeys[ttp_id];
  }

  function get_ttp_params(uint256 ttp_id) public view returns(G.G1Point[] memory) {
      return (ttp_params[ttp_id]);
  }

//PARAMSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS WALA CONTENT

// mapping(uint256 => G.G1Point[]) private hsmapping; 
// mapping(uint256 => G.G2Point) private alphamapping; 
// mapping(uint256 => G.G2Point[]) private betamapping; 
// mapping(uint256 => G.G2Point[]) private opkmapping; 
// function set_params(uint256 serviceID, G.G1Point[] memory _hs, G.G2Point memory _alpha, G.G2Point[] memory _beta) public { //, G.G2Point[] memory _opk
//         // delete hs;
//         // delete beta;
//         // delete opk;
//         for(uint256 i=0; i < _hs.length; i++) {
//             hsmapping[serviceID].push(_hs[i]);   
//         }
//         alphamapping[serviceID] = _alpha;

//         for(uint256 h=0; h < _beta.length; h++) {
//             betamapping[serviceID].push(_beta[h]);
//         }
        
//     }

// function get_hs(uint256 serviceID) public view returns (G.G1Point[] memory) {
//     return hsmapping[serviceID];
// }

// function get_alpha(uint256 serviceID) public view returns (G.G2Point memory) {
//     return alphamapping[serviceID];
// }

// function get_beta(uint256 serviceID) public view returns (G.G2Point[] memory) {
//     return betamapping[serviceID];
// }



// function get_hs(uint256 serviceID,uint i) public view returns (G.G1Point memory) {
//     return hsmapping[serviceID][i];
// }

// function get_beta(uint256 serviceID,uint i) public view returns (G.G2Point memory) {
//     return betamapping[serviceID][i];
// }

// function get_opk(uint256 serviceID,uint i) public view returns (G.G2Point memory) {
//   return opkmapping[serviceID][i];
// }


//PARAMS WALA 



  //new things ends here
//uint common;

// mapping(uint256 => G.G1Point[]) private hsmapping; 
// mapping(uint256 => G.G2Point) private alphamapping; 
// mapping(uint256 => G.G2Point[]) private betamapping; 
// function set_params(uint256 serviceID, G.G1Point[] memory _hs, G.G2Point memory _alpha, G.G2Point[] memory _beta) public { //, G.G2Point[] memory _opk
//         // delete hs;
//         // delete beta;
//         // delete opk;
//         for(uint256 i=0; i < _hs.length; i++) {
//             hsmapping[serviceID].push(_hs[i]);   
//         }
//         alphamapping[serviceID] = _alpha;

//         for(uint256 h=0; h < _beta.length; h++) {
//             betamapping[serviceID].push(_beta[h]);
//         }
        
//     }

// function get_hs(uint256 serviceID) public view returns (G.G1Point[] memory) {
//     return hsmapping[serviceID];
// }

// function get_alpha(uint256 serviceID) public view returns (G.G2Point memory) {
//     return alphamapping[serviceID];
// }

// function get_beta(uint256 serviceID) public view returns (G.G2Point[] memory) {
//     return betamapping[serviceID];
// }

mapping(uint256 => uint256) common;
function setCommonParameter(uint256 serviceID,uint256 val) public{   
    common[serviceID] = val;
}

function getCommonParameter(uint256 serviceID) public view returns(uint256){
    return common[serviceID];
}

// mapping(uint256 => mapping(uint256 => uint256[])) includeIndex;

function indexing(uint256 TTPId, uint256 ServiceId,uint256[] memory data) public {   //This will map (TTPId,ServiceId)=>[includeIndex]
    includeIndex[TTPId][ServiceId] = data;
//   return true;
}

function return_indexing(uint256 TTPId, uint256 ServiceId) public view returns(uint256[] memory success) { //This will return map (TTPId,ServiceId)=>[includeIndex]
    return includeIndex[TTPId][ServiceId];
    
}



    function setTotalOpener(uint256 serviceID, uint256 val) public{
        totalOpener[serviceID] = val;
    }

    function getTotalOpener(uint256 serviceID) public view returns(uint256){
        return totalOpener[serviceID];
    }

    function setThresholdOpener(uint256 serviceID, uint256 val) public{
        thresholdOpener[serviceID] = val;
    }

    function getThresholdOpener(uint256 serviceID) public view returns(uint256){
        return thresholdOpener[serviceID];
    }


    function setTotalValidator(uint256 serviceID, uint256 val) public{
        totalValidator[serviceID] = val;
    }

    function getTotalValidator(uint256 serviceID) public view returns(uint256){
        return totalValidator[serviceID];
    }

    function setThresholdValidator(uint256 serviceID, uint256 val) public{
        thresholdOpener[serviceID] = val;
    }

    function getThresholdValidator(uint256 serviceID) public view returns(uint){
        return thresholdOpener[serviceID];
    }

    // function getThresholdValidator(uint256 serviceID) public view returns(uint){
    //     return thresholdOpener[serviceID];
    // }


function addID(uint256 servID) public 
{   
    
   serviceIDList.push(servID);  
}
    
function addName(string memory name) public 
{   
    serviceNameList.push(name);
    
}

    function getID() public view returns(uint256[] memory)                           // We have to check this once
    {
    return serviceIDList;
    }

    function getName() public view returns(string[] memory)                         // We have to check this once
    {
    return serviceNameList;
    }

    // function getTotalList() public view returns (uint)                              // We have to check this once
    // {
    // return serialIDList.length;
    // }
// ====================================================================================================
// =================================================================================================
    mapping(uint256 => uint256) totalAttributes; //serviceID - > number_of_attributes
   // mapping(uint256 => string) desc;
    //mapping(uint256 => string) public attribute_name;
    //mapping(string => string) public attribute_type;
    //mapping(string => string) public attribute_remark;
    //mapping(uint256 => uint256) number_of_attributes;
mapping(uint256 => string) serviceName;
mapping(uint256 => string) serviceDesc;
mapping(uint256 => mapping(uint256 => string)) AttribteName;
mapping(uint256 => mapping(uint256 => string)) AttribteType;
mapping(uint256 => mapping(uint256 => string)) AttribteRemarks;


    function setServiceDescription(uint256 serviceID, string memory descc) public{
        serviceDesc[serviceID] = descc;
    }

    function getServiceDescription(uint256 serviceID) public view returns(string memory){
        return serviceDesc[serviceID];

    }

    function setServiceName(uint256 serviceID, string memory _name) public{
        serviceName[serviceID] = _name;
    }

    function getServiceName(uint256 serviceID) public view returns(string memory){
        return serviceName[serviceID];

    }

    


     function getTotalAttributes(uint256 serviceID) public view returns(uint256){
      return totalAttributes[serviceID]; //access the local variable
    }

    function setTotalAttributes(uint256 serviceID, uint256 ss) public {
      totalAttributes[serviceID]=ss; //access the local variable
    }
    

    
    function setName(uint256 serviceID,uint256 attrub_num, string memory _val) public 
    {
    if(attrub_num<=getTotalAttributes(serviceID)){
        
        AttribteName[serviceID][attrub_num] = _val;
    }
    }
    
    function getName(uint256 serviceID,uint256 attrub_num) public view returns(string memory){   
            return  AttribteName[serviceID][attrub_num];
            
          }


    function setType(uint256 serviceID,uint256 attrub_num, string memory _val) public {
            if(attrub_num<=getTotalAttributes(serviceID)){
              
              AttribteType[serviceID][attrub_num] = _val;
            }
          }
    
    function getType(uint256 serviceID,uint256 attrub_num) public view returns(string memory){   
            return  AttribteType[serviceID][attrub_num];
            
          }


    function setRemark(uint256 serviceID,uint256 attrub_num, string memory _val) public {
            if(attrub_num<=getTotalAttributes(serviceID)){
              
              AttribteRemarks[serviceID][attrub_num] = _val;
            }
          }
    
    function getRemark(uint256 serviceID,uint256 attrub_num) public view returns(string memory){   
            return  AttribteRemarks[serviceID][attrub_num];
            
          }


    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

// function setDesc(string memory serviceID, string memory description) public {
//         stringdesc[serviceID] = description;
//     }


//     function getDesc(string memory serviceID) public view returns(string memory){
//         return desc[serviceID];
//     }
}