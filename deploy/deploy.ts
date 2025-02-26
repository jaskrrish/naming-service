// scripts/deploy.ts
import { ethers } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // 1. Deploy PushRegistry
    console.log("Deploying PushRegistry...");
    const PushRegistry = await ethers.getContractFactory("PushRegistry");
    const pushRegistry = await PushRegistry.deploy();
    await pushRegistry.waitForDeployment();
    console.log("PushRegistry deployed to:", await pushRegistry.getAddress());

    // 2. Deploy PriceOracle
    const prices = [
        ethers.parseEther("1"),     // 1 letter
        ethers.parseEther("0.5"),   // 2 letters
        ethers.parseEther("0.3"),   // 3 letters
        ethers.parseEther("0.1"),   // 4 letters
        ethers.parseEther("0.05"),  // 5+ letters
    ];
    
    console.log("Deploying PriceOracle...");
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    const priceOracle = await PriceOracle.deploy(prices);
    await priceOracle.waitForDeployment();
    console.log("PriceOracle deployed to:", await priceOracle.getAddress());

    // 3. Deploy BaseRegistrar
    console.log("Deploying BaseRegistrar...");
    const BaseRegistrar = await ethers.getContractFactory("BaseRegistrar");
    const baseNode = ethers.namehash("push");
    const pushRegistrar = await BaseRegistrar.deploy(
        await pushRegistry.getAddress(),
        baseNode
    );
    await pushRegistrar.waitForDeployment();
    console.log("BaseRegistrar deployed to:", await pushRegistrar.getAddress());

    // 4. Deploy PublicResolver
    console.log("Deploying PublicResolver...");
    const PublicResolver = await ethers.getContractFactory("PublicResolver");
    const resolver = await PublicResolver.deploy(
        await pushRegistry.getAddress(),
        await pushRegistrar.getAddress() // trustedController is the registrar
    );
    await resolver.waitForDeployment();
    console.log("PublicResolver deployed to:", await resolver.getAddress());

    // 5. Deploy RegistrarController
    console.log("Deploying RegistrarController...");
    const RegistrarController = await ethers.getContractFactory("PushRegistrarController");
    const minCommitmentAge = 60; // 1 minute
    const maxCommitmentAge = 24 * 60 * 60; // 24 hours
    const registrarController = await RegistrarController.deploy(
        await pushRegistrar.getAddress(),
        await priceOracle.getAddress(),
        minCommitmentAge,
        maxCommitmentAge
    );
    await registrarController.waitForDeployment();
    console.log("RegistrarController deployed to:", await registrarController.getAddress());

    // 6. Deploy ReverseRegistrar
    console.log("Deploying ReverseRegistrar...");
    const ReverseRegistrar = await ethers.getContractFactory("ReverseRegistrar");
    const reverseRegistrar = await ReverseRegistrar.deploy(await pushRegistry.getAddress());
    await reverseRegistrar.waitForDeployment();
    console.log("ReverseRegistrar deployed to:", await reverseRegistrar.getAddress());

    // Setup steps
    console.log("\nPerforming setup steps...");

    // 1. Set controller in registrar
    const controllerTx = await pushRegistrar.addController(await registrarController.getAddress());
    await controllerTx.wait();
    console.log("Controller added to Registrar");

    // 2. Set baseNode owner in registry to registrar
    const label = ethers.keccak256(ethers.toUtf8Bytes("push"));
    const setSubnodeTx = await pushRegistry.setSubnodeOwner(
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        label,
        await pushRegistrar.getAddress()
    );
    await setSubnodeTx.wait();
    console.log("Registrar set as owner of baseNode in Registry");

    // 3. Set resolver for baseNode
    const setResolverTx = await pushRegistrar.setResolver(await resolver.getAddress());
    await setResolverTx.wait();
    console.log("Resolver set for baseNode");

    // 4. Setup ReverseRegistrar
    // Set addr.reverse node owner to ReverseRegistrar
    const reverseLabel = ethers.keccak256(ethers.toUtf8Bytes("reverse"));
    const addrLabel = ethers.keccak256(ethers.toUtf8Bytes("addr"));
    const reverseNode = ethers.namehash("reverse");
    
    // First set up "reverse" node
    await pushRegistry.setSubnodeOwner(
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        reverseLabel,
        deployer.address
    );
    console.log("Reverse node set up");

    // Then set up "addr.reverse" node
    await pushRegistry.setSubnodeOwner(
        reverseNode,
        addrLabel,
        await reverseRegistrar.getAddress()
    );
    console.log("addr.reverse node owner set to ReverseRegistrar");

    // Set default resolver for ReverseRegistrar
    await reverseRegistrar.setDefaultResolver(await resolver.getAddress());
    console.log("Default resolver set for ReverseRegistrar");

    console.log("\nDeployment and setup completed!");
    console.log("\nDeployed Contracts:");
    console.log("-------------------");
    console.log("PushRegistry:", await pushRegistry.getAddress());
    console.log("PriceOracle:", await priceOracle.getAddress());
    console.log("BaseRegistrar:", await pushRegistrar.getAddress());
    console.log("PublicResolver:", await resolver.getAddress());
    console.log("RegistrarController:", await registrarController.getAddress());
    console.log("ReverseRegistrar:", await reverseRegistrar.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });