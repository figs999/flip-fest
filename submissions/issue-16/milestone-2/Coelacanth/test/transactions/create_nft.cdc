import ExampleNFT from 0xf8d6e0586b0a20c7

transaction(bytes: [UInt8]) {
  let minter : &ExampleNFT.NFTMinter
  let collection : &ExampleNFT.Collection
  
  prepare(acct: AuthAccount) {
    self.minter = acct.borrow<&ExampleNFT.NFTMinter>(from: /storage/NFTMinter)!
    self.collection = acct.borrow<&ExampleNFT.Collection>(from: /storage/NFTCollection)!
  }

  execute {
    self.minter.mintNFT(recipient: self.collection, name: "First", description: "The first in the collection", imgBytes: bytes)
  }
}
