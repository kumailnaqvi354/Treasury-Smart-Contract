// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IUniswap.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract Treasury is Ownable, ERC20, IERC721Receiver {
    using SafeMath for uint256;

    uint256 public dividendRatio;
    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = -MIN_TICK;
    int24 private constant TICK_SPACING = 60;
    uint256 UniswapPositionTokenId;
    string public NAME = "Treasury Smart Contract";

    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    address public constant USDT = 0xC2C527C0CACF457746Bd31B2a698Fe89de2b6d49;
    address public constant DAI = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;
    struct user {
        uint256 _usdtTokens;
        uint256 _daiTokens;
    }

    mapping(address => user) public userLiquidity;

    event LiquidityMint(
        uint tokenId,
        uint128 liquidity,
        uint amount0,
        uint amount1
    );
    event withdrawLiquidity(uint amount0, uint amount1);

    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
    {}

    function onERC721Received(
        address operator,
        address from,
        uint tokenId,
        bytes calldata
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}

    fallback() external payable {}

    // @notice Deposit stable token to the Treasure Tokens
    // @notice params The parameters are necessary for the Liquidity Provision and K value Calculation
    function depositTokens(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external {
        require(
            amount0 > 0 && amount1 > 0,
            "Amount should be greater than zero"
        );
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        uint256 k;
        unchecked {
            k = amount0 * amount1;
        }
        _mint(msg.sender, k);
    }

    function createPosition() external onlyOwner returns (uint256) {
        IERC20(USDT).approve(
            address(nonfungiblePositionManager),
            _balanceOf(USDT)
        );
        IERC20(DAI).approve(
            address(nonfungiblePositionManager),
            _balanceOf(DAI)
        );

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: USDT,
                token1: DAI,
                fee: 3000,
                tickLower: (MIN_TICK / TICK_SPACING) * TICK_SPACING,
                tickUpper: (MAX_TICK / TICK_SPACING) * TICK_SPACING,
                amount0Desired: _balanceOf(USDT),
                amount1Desired: _balanceOf(DAI),
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = nonfungiblePositionManager.mint(params);
        UniswapPositionTokenId = tokenId;

        emit LiquidityMint(tokenId, liquidity, amount0, amount1);
        return liquidity;
    }
    function withdrawLiquidityFromPool() external {
        removeUniswapLiquidity();
    }

    function _balanceOf(address token) internal returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    function removeUniswapLiquidity() internal {
        uint256 _lpBalance = balanceOf(msg.sender);
        uint128 userShare;
        unchecked {
            userShare = (uint128(_lpBalance) * 1e18) / uint128(totalSupply());
        }
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: UniswapPositionTokenId,
                    liquidity: userShare,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager
            .decreaseLiquidity(params);

        emit withdrawLiquidity(amount0, amount1);
    }

   
}
