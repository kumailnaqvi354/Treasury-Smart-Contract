pragma solidity ^0.8.0;

interface ITreasury {

    function depositTokens(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external;
     function addLiquidityToProtocols() external;

function calculateAPY(address _caller) external view returns(uint256, uint256);
function withdrawLiquidityFromPool() external;
function setRatio(uint256[] calldata _value) external;


}