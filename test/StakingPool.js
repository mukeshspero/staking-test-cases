const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MyContract", function () {
  let travelToken;
  let stakingPool;
  let owner;
  let addr1;
  let addr2;
  let addrs;
  let name = "Travel Deals";
  let symbol = "CTRAVL";
  let decimals = 4;
  let supply = 100000; //100K

  let rewards = 500000000; //50K

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    let Token = await ethers.getContractFactory("TokenContract");
    let StakingPool = await ethers.getContractFactory("StakingPool");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy a new instance of the contract before each test.
    travelToken = await Token.deploy(name, symbol, decimals);

    await travelToken.mint(supply);

    // let stakingToken = travelToken.address; //depriated
    let stakingToken = travelToken.target;
    let poolDurationDays = 3;
    let lockinDurationDays = 0;

    stakingPool = await StakingPool.deploy(
      stakingToken,
      poolDurationDays,
      lockinDurationDays
    );

    // Add rewards to the pool
    await travelToken.approve(stakingPool.target, rewards);
    await stakingPool.addRewards(rewards);

    // Transfer some tokens to addr1 and addr2
    await travelToken.transfer(addr1.address, 20000000);
    await travelToken.transfer(addr2.address, 70000000);
  });

  /************************* StakingPool */

  describe("Staking", function () {
    it("Should have the appropriate number of rewards", async function () {
      let totalPoolRewards = await stakingPool.totalPoolRewards();
      totalPoolRewards = Number(totalPoolRewards) / 10 ** 18;
      expect(totalPoolRewards).to.equal(rewards);
    });

    it("Should revert with the right error if reward is already added", async function () {
      let rewards = 70000000; //7K
      // Approve and add rewards
      await travelToken.approve(stakingPool.target, rewards);
      await expect(stakingPool.addRewards(rewards)).to.be.revertedWith(
        "Already added the reward token to the contract."
      );
    });

    it("Should allow users to stake tokens", async function () {
      let amount = 20000000; //2K
      // Approve and stake tokens
      await travelToken.connect(addr1).approve(stakingPool.target, amount);
      await stakingPool.connect(addr1).stakeTokens(amount);
      // Check the staked amount
      let stakedAmount = await stakingPool.totalStaked();
      stakedAmount = Number(stakedAmount) / 10 ** (18 - decimals);
      expect(stakedAmount).to.equal(amount);
    });
  });
});
