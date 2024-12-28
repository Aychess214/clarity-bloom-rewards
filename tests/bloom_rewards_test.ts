import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure that partner registration works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const partner = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('bloom_rewards', 'register-partner', [
        types.principal(partner.address),
        types.ascii("Eco Store"),
        types.uint(100)
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), true);
    
    // Verify partner info
    let infoBlock = chain.mineBlock([
      Tx.contractCall('bloom_rewards', 'get-partner-info', [
        types.principal(partner.address)
      ], deployer.address)
    ]);
    
    const partnerInfo = infoBlock.receipts[0].result.expectOk().expectSome();
    assertEquals(partnerInfo.name, "Eco Store");
    assertEquals(partnerInfo['sustainability-score'], types.uint(100));
  }
});

Clarinet.test({
  name: "Test point awarding and redemption flow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const partner = accounts.get('wallet_1')!;
    const user = accounts.get('wallet_2')!;
    
    // Register partner first
    let setup = chain.mineBlock([
      Tx.contractCall('bloom_rewards', 'register-partner', [
        types.principal(partner.address),
        types.ascii("Eco Store"),
        types.uint(2)
      ], deployer.address)
    ]);
    
    // Award points
    let awardBlock = chain.mineBlock([
      Tx.contractCall('bloom_rewards', 'award-points', [
        types.principal(user.address),
        types.uint(100),
        types.principal(partner.address)
      ], partner.address)
    ]);
    
    assertEquals(awardBlock.receipts[0].result.expectOk(), types.uint(200));
    
    // Check user stats
    let statsBlock = chain.mineBlock([
      Tx.contractCall('bloom_rewards', 'get-user-stats', [
        types.principal(user.address)
      ], deployer.address)
    ]);
    
    const userStats = statsBlock.receipts[0].result.expectOk().expectSome();
    assertEquals(userStats['total-points'], types.uint(200));
    assertEquals(userStats.purchases, types.uint(1));
    
    // Test redemption
    let redeemBlock = chain.mineBlock([
      Tx.contractCall('bloom_rewards', 'redeem-points', [
        types.uint(50),
        types.principal(user.address)
      ], user.address)
    ]);
    
    assertEquals(redeemBlock.receipts[0].result.expectOk(), true);
  }
});