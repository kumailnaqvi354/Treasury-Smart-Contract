import { expect } from "chai";
import { ethers } from "hardhat";

describe("Treasury", function () {
    it("Should return name Token", async function () {
      const Treasury = await ethers.getContractFactory("Treasury");
      const treasury = await Treasury.deploy("50000000000000000000", "LPTokens", "LP");
      await treasury.deployed();
//   console.log("here ",await treasury.NAME());
  
      expect(await treasury.NAME()).to.equal("Treasury Smart Contract");
    });
  });
  