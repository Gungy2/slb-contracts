require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    local: {
      url: "http://127.0.0.1:7545",
      accounts: ['0xd0be7d254e16af996e50bce06cd6fe1f96cb9d3183062127948c0f190aefe6a1', '0xa14849822b19d3c9ba9874b635c968d81e64a9905f6b1c574657ef09025cfca1'],
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.18",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
};
