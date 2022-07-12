# EscrowPaymentSplitter

## Escrow

- Process
1. The user registers the escrow information in the GEN escrow contract through addEscrowPayment().
2. After escrow registration, if ETH or GEN is paid, the NFT owner is changed when 1 block confirmation (10-20 seconds) is reached. (NFT withdrawal is possible only after 12 confirmations after escrow payment)
3. The paid ETH or GEN is distributed to Pinetree and Creator Royalty Fee, and the remaining amount is paid to the NFT seller.
