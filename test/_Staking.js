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

  // Add your test cases here
  describe("Token", function () {
    it("Should have the correct name, symbol and decimal", async function () {
      expect(await travelToken.name()).to.equal(name);
      expect(await travelToken.symbol()).to.equal(symbol);
      expect(await travelToken.decimals()).to.equal(decimals);
    });

    it("Should have the right amount of supply", async function () {
      const totalSupply = BigInt(supply) * BigInt(10 ** decimals);
      expect(await travelToken.totalSupply()).to.equal(totalSupply);
    });

    // it("Should transfer tokens between accounts", async function () {
    //   // Transfer 20K tokens from owner to addr1
    //   await travelToken.transfer(addr1.address, 20000000);

    //   const addr1Balance = await travelToken.balanceOf(addr1.address);
    //   expect(BigInt(addr1Balance)).to.equal(20000000);

    //   const ownerBalance = await travelToken.balanceOf(owner.address);
    //   expect(ownerBalance).to.equal(800000000);
    // });
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
