require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  networks: {
    sepolia: {
      url: "https://sepolia.optimism.io",
      accounts: [
        `1183a35f7e8addd3400d28151401019694f556ce7c55c5fb0b14b5ca729f6fe0`,
      ],
    },
  },
};
