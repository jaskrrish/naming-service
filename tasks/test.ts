// scripts/test-registration.ts
import { ethers } from "hardhat";

async function main() {
  // Contract addresses from deployment
  const ADDRESSES = {
    REGISTRY: "0x3a29DADC6d65423D1f19B2EDa11B637f0b4598e5",
    REGISTRAR: "0xe7AeDf481bc90f200f777B3f4a9bb05F6350CEa3",
    CONTROLLER: "0x823A3aB905a1504079746f981DB55d5BDa3296eF",
    RESOLVER: "0xfa4498a121458FDED70f93491d1587e3BE5059D8",
    PRICE_ORACLE: "0x504b1157d1D7f1976bedA8E1c76dF022164D2597",
  };

  const [signer] = await ethers.getSigners();
  console.log("Testing with account:", signer.address);

  // Get contract instances
  const controller = await ethers.getContractAt("PushRegistrarController", ADDRESSES.CONTROLLER);
  const resolver = await ethers.getContractAt("PublicResolver", ADDRESSES.RESOLVER);
  const registrar = await ethers.getContractAt("BaseRegistrar", ADDRESSES.REGISTRAR);

  // Test parameters
  const name = "tess";
  const duration = 365 * 24 * 60 * 60; // 1 year in seconds
  const secret = ethers.id("mysecret");
  const owner = signer.address;

  console.log("\nStarting registration test for:", name + ".push");

  try {
    // 1. Check if name is available
    console.log("\nChecking name availability...");
    const isAvailable = await controller.available(name);
    if (!isAvailable) {
      throw new Error("Name is not available");
    }
    console.log("Name is available!");

    // 2. Get registration price
    console.log("\nGetting registration price...");
    const price = await controller.rentPrice(name, duration);
    console.log("Registration price:", ethers.formatEther(price), "CRO");

    // 3. Make commitment
    console.log("\nMaking commitment...");
    const commitment = await controller.makeCommitment(name, owner, duration, secret, ADDRESSES.RESOLVER, []);
    console.log("Commitment created:", commitment);

    // 4. Submit commitment
    console.log("\nSubmitting commitment...");
    const commitTx = await controller.commit(commitment);
    await commitTx.wait();
    console.log("Commitment submitted. Transaction:", commitTx.hash);

    // 5. Wait for minimum commitment age (60 seconds in our case)
    console.log("\nWaiting for commitment age (70 seconds)...");
    await new Promise((resolve) => setTimeout(resolve, 70000));

    // 6. Register the name
    console.log("\nRegistering name...");
    const registerTx = await controller.register(name, owner, duration, secret, ADDRESSES.RESOLVER, [], {
      value: price,
    });
    await registerTx.wait();
    console.log("Name registered! Transaction:", registerTx.hash);

    // 7. Verify registration
    console.log("\nVerifying registration...");
    const label = ethers.keccak256(ethers.toUtf8Bytes(name));
    const tokenId = ethers.toBigInt(label);
    const registeredOwner = await registrar.ownerOf(tokenId);
    console.log("Registered owner:", registeredOwner);
    console.log("Expected owner:", owner);
    console.log("Registration successful:", registeredOwner === owner);

    // 8. Set resolver records
    console.log("\nSetting resolver records...");
    const node = ethers.keccak256(ethers.concat([ethers.namehash("push"), ethers.keccak256(ethers.toUtf8Bytes(name))]));

    // Set address record
    const setAddrTx = await resolver.setAddr(node, owner);
    await setAddrTx.wait();
    console.log("Address record set");

    // Set text record
    const setTextTx = await resolver.setText(node, "description", "My PUSH name");
    await setTextTx.wait();
    console.log("Text record set");

    // Set name record
    const setNameTx = await resolver.setName(node, name);
    await setNameTx.wait();
    console.log("Name record set");

    // 9. Verify resolver records
    console.log("\nVerifying resolver records...");
    const resolvedAddress = await resolver.addr(node);
    const resolvedText = await resolver.text(node, "description");
    const resolvedName = await resolver.name(node);
    console.log("Resolved address:", resolvedAddress);
    console.log("Resolved text:", resolvedText);
    console.log("Resolved name:", resolvedName);

    console.log("\nAll tests completed successfully!");
  } catch (error) {
    console.error("Error during testing:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

/**
   * 
   * 
   * Starting registration test for: tess.push

Checking name availability...
Name is available!

Getting registration price...
Registration price: 36.5 CRO

Making commitment...
Commitment created: 0xef94167846f7fd92673e746998091c4138209a3ab47da97bdb4f114a0322b19e

Submitting commitment...
Commitment submitted. Transaction: 0x1db2c1a752e18807cb6b58e69ca078eaa8ab2099a8d03c476b6060996836f484

Waiting for commitment age (70 seconds)...

Registering name...
Name registered! Transaction: 0xf683c8a3eb011f8380c016e804a86c638e1b9dcfa259dff40eebebd6687afc1d

Verifying registration...
Registered owner: 0xB207F0CE9D53DBFC5C7c2f36A8b00b3315464529
Expected owner: 0xB207F0CE9D53DBFC5C7c2f36A8b00b3315464529
Registration successful: true

Setting resolver records...
Address record set
Text record set
Name record set

Verifying resolver records...
Resolved address: 0xB207F0CE9D53DBFC5C7c2f36A8b00b3315464529
Resolved text: My PUSH name
Resolved name: tess


   * 
   * 
   */
