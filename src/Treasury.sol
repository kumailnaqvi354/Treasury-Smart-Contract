// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IUniswap.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Treasury is Ownable, ERC20 {
    using SafeMath for uint256;

    uint256 public dividendRatio;
    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = -MIN_TICK;
    int24 private constant TICK_SPACING = 60;

    string public NAME = "Treasury Smart Contract";

    ISwapRouter constant router =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    address public USDT = 0xC2C527C0CACF457746Bd31B2a698Fe89de2b6d49;
    address public DAI = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;
    struct user {
        uint256 _usdtTokens;
        uint256 _daiTokens;
    }

    mapping(address => user) public userLiquidity;

    constructor(
        uint256 _ratio,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        dividendRatio = _ratio;
    }

    receive() external payable {}

    fallback() external payable {}

    // @notice Deposit stable token to the Treasure Tokens
    // @notice params The parameters are necessary for the Liquidity Provision and K value Calculation
    function DepositTokens(
        uint256 amount1,
        uint256 amount2,
        address token1,
        address token2
    ) external {
        require(
            amount1 > 0 && amount2 > 0,
            "Amount should be greater than zero"
        );
        if (USDT == token1 && token2 == DAI) {
            IERC20(token1).transferFrom(msg.sender, address(this), amount1);
            IERC20(token2).transferFrom(msg.sender, address(this), amount2);
            uint _total = amount1.add(amount2);
            user memory _cache = userLiquidity[msg.sender];
            _cache._usdtTokens = _cache._usdtTokens.add(amount1);
            _cache._daiTokens = _cache._daiTokens.add(amount2);
            userLiquidity[msg.sender] = _cache;

            _mint(msg.sender, _total);
        }
    }
}
