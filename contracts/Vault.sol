pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRouter {
	function getPair(IERC20 tokenA, IERC20 tokenB) external view returns (address);
}

interface IOracle {
	function calcMustardPrice(IERC20 token, address pair) external view returns (uint256);
}

interface IMintable {
	function mint(uint256 amount) external;
	function burn(uint256 amount) external;
}

interface ITreasury {
	function getTokenTo(address _baseToken, uint256 _amount, address _to) external payable;
	function getETHTo(uint256 _amount, address payable _to) external;
}

contract Vault is Ownable {

	struct debtInfo {
		uint256 collateral; // 담보액
		uint256 loan;       // 대출액
	}

	address[] public loaners; // 대출자 목록

	address public treasury;  // 금고 주소
	address public oracle;    // 오라클 주소
	address public router;    // 라우터 주소
	IERC20 public mUST;       // mUST 토큰
	IERC20 public baseToken;  // 기본 토큰

	mapping(address => debtInfo) userInfo; // 사용자 정보

	constructor(address _mUST, address _treasury, address _oracle, address _router, address _baseToken) {
		require(_mUST != address(0), "Vault: _mUST cannot be zero address");
		require(_treasury != address(0), "Vault: _treasury cannot be zero address");
		require(_oracle != address(0), "Vault: _oracle cannot be zero address");
		require(_router != address(0), "Vault: _router cannot be zero address");
		// Audit: 이후에 baseToken의 값을 수정할 수 있는 부분이 없기 때문에 _baseToken이 address(0)인지 확인 필요
		require(_baseToken != address(0), "Vault: _baseToken cannot be zero address");

		treasury = _treasury;
		oracle = _oracle;
		router = _router;
		mUST = IERC20(_mUST);
		baseToken = IERC20(_baseToken);
	}

	// 대출자 추가
	function _addLoaner(address _loaner) private {
		loaners.push(_loaner);
	}

	// 대출자 삭제
	// 입력 받은 대출자 주소를 영주소로 변경하는 방식으로 삭제
	function _deleteLoaner(address _loaner) private {
		for(uint i=0; i<loaners.length; i++) {
			// 의문점: 삭제가 아니라 영주소로 변경하는 이유
			if(loaners[i] == _loaner) { 
				loaners[i] = address(0);
				break;
			}
		}
	}

	// 담보금 추가
	function addColletral(uint256 amount) public {
		// Audit: amount가 0이면 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(amount > 0, "Vault: amount must be greater than zero");
		// baseToken을 실행자에서 금고(treasury)로 이동
		baseToken.transferFrom(msg.sender, treasury, amount);
		// 사용자의 담보금 추가
		userInfo[msg.sender].collateral += amount;
	}

	// 대출 - baseToken을 담보로 대출하는 함수
	function deposit(uint256 amount) public {
		// Audit: amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(amount > 0, "Vault: amount cannot be zero");
		// Audit: 사용자에게 충분한 잔액이 있는지 확인 필요
		require(baseToken.balanceOf(msg.sender) >= amount, "Vault: insufficient balance");
		// Audit: 사용자의 토큰을 이 컨트랙트가 사용할 수 있는지 확인 필요
		require(baseToken.allowance(msg.sender, address(this)) >= amount, "Vault: insufficient allowance");
		
		// router를 통해 baseToken과 mUST의 페어 주소를 가져옴
		address pair = IRouter(router).getPair(baseToken, mUST);
		// 오라클을 통해 baseToken과 mUST의 페어 가격을 가져옴
		uint256 price = IOracle(oracle).calcMustardPrice(baseToken, pair);
		// 대출액 계산(대출은 담보물의 80% 가치로 발행)
		uint256 mUSTAmt = amount * 1e18 * 4 / price / 5;
		// 사용자의 담보금이 0이면 신규 사용자이기 때문에 대출자 추가
		if (userInfo[msg.sender].collateral == 0) { _addLoaner(msg.sender); }

		// Audit: 사용자의 담보금, 대출액 상태 관리 후 실행하도록 수정
		// 사용자의 담보금, 대출액 추가 (상태 관리)
		userInfo[msg.sender].collateral += amount;
		userInfo[msg.sender].loan += mUSTAmt;

		// baseToken을 실행자에서 금고(treasury)로 이동 (실행)
		_safeTransferFrom(address(baseToken), msg.sender, treasury, amount);

		// mUST 발행 후 사용자에게 전송
		IMintable(address(mUST)).mint(mUSTAmt);
		mUST.transfer(msg.sender, mUSTAmt);
	}

	// Audit: safeTransferFrom 함수는 외부에서 호출하지 않는 함수이기 때문에 함수명 앞에 _를 붙이는 것이 좋음
	function _safeTransferFrom(address token, address from, address to, uint256 amount) private {
		// token.call을 통해 transferFrom 함수를 호출하고 성공 여부를 확인
		(bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount)
        );
        require(success, "Vault: safeTransferFrom is not successful");
	}

	// 대출 상환 - mUST를 사용하여 baseToken을 출금하는 함수
	function withdraw(uint256 amount) public virtual {
		// Audit: amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(amount > 0, "Vault: amount cannot be zero");
		// Audit: 사용자에게 충분한 mUST가 있는지 확인 필요
		require(mUST.balanceOf(msg.sender) >= amount, "Vault: insufficient balance");
		// Audit: 사용자의 mUST를 이 컨트랙트가 사용할 수 있는지 확인 필요
		require(mUST.allowance(msg.sender, address(this)) >= amount, "Vault: insufficient allowance");
		
		// 출금액 계산
		uint256 retAmt = amount * userInfo[msg.sender].collateral  / userInfo[msg.sender].loan;
		// mUST를 실행자에서 금고(this)로 이동 (실행)
		mUST.transferFrom(msg.sender, address(this), amount); // 받고
		// 사용자의 대출액 감소
		userInfo[msg.sender].loan -= amount;
		// 금고(treasury)에서 baseToken을 사용자에게 전송
		ITreasury(treasury).getTokenTo(address(baseToken), retAmt, msg.sender);
		// 사용자의 대출액이 0이면 대출자 삭제
		if(userInfo[msg.sender].loan == 0) {
			userInfo[msg.sender].collateral = 0;
			_deleteLoaner(msg.sender);
		} else {
			userInfo[msg.sender].collateral -= retAmt;
		}
		// mUST 소각
		IMintable(address(mUST)).burn(amount);
	}

	// 대출 상환 - mUST를 사용하여 ETH를 출금하는 함수
	function withdrawETH(uint256 amount) public {
		// Audit: amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(amount > 0, "Vault: amount cannot be zero");
		// Audit: 사용자에게 충분한 mUST가 있는지 확인 필요
		require(mUST.balanceOf(msg.sender) >= amount, "Vault: insufficient balance");
		// Audit: 사용자의 mUST를 이 컨트랙트가 사용할 수 있는지 확인 필요
		require(mUST.allowance(msg.sender, address(this)) >= amount, "Vault: insufficient allowance");
		
		// 출금액 계산
		uint256 retAmt = amount * userInfo[msg.sender].collateral  / userInfo[msg.sender].loan;
		
		// Audit: 사용자의 대출액 감소 (상태 관리) 순서 조정
		// 사용자의 대출액 감소 (상태 관리)
		userInfo[msg.sender].loan -= amount;
		// mUST를 실행자에서 금고(this)로 이동 (실행)
		mUST.transferFrom(msg.sender, address(this), amount); // 받고
		// 금고(treasury)에서 ETH을 사용자에게 전송
		ITreasury(treasury).getETHTo(retAmt, payable(msg.sender));
		
		// 사용자의 대출액이 0이면 대출자 삭제
		if(userInfo[msg.sender].loan == 0) {
			userInfo[msg.sender].collateral = 0;
			_deleteLoaner(msg.sender);
		} else {
			userInfo[msg.sender].collateral -= retAmt;
		}
		IMintable(address(mUST)).burn(amount);
	}

	// 청산 로직
	function _liquidate(address loaner) private {
		address pair = IRouter(router).getPair(baseToken, mUST);
		uint256 price = IOracle(oracle).calcMustardPrice(baseToken, pair);
		if (userInfo[loaner].loan >= userInfo[loaner].collateral * 1e18 / price) {
			userInfo[address(0)].collateral += userInfo[loaner].collateral;
			userInfo[address(0)].loan += userInfo[loaner].loan * 51 / 50;
			userInfo[loaner].collateral = 0;
			userInfo[loaner].loan = 0;
			_deleteLoaner(loaner);
		}
	}

	// 청산
	function liquidate() public {
		for(uint i=0; i<loaners.length; i++) {
			_liquidate(loaners[i]);
		}
	}

	// 청산된 자금 회수
	function repay(uint256 amount) public {
		uint256 retAmt = amount * userInfo[address(0)].collateral  / userInfo[address(0)].loan;
		mUST.transferFrom(msg.sender, address(this), amount); // 받고
		userInfo[address(0)].loan -= amount;
		ITreasury(treasury).getTokenTo(address(baseToken), retAmt, msg.sender);
		userInfo[address(0)].collateral -= retAmt;
		if(userInfo[address(0)].loan == 0) {
			userInfo[address(0)].collateral = 0;
		}
		IMintable(address(mUST)).burn(amount);
	}

	function getLiquidationInfo() public returns (uint256, uint256) {
		return (userInfo[address(0)].loan, userInfo[address(0)].collateral);
	}

	receive() external payable { }
	fallback() external payable { }
}