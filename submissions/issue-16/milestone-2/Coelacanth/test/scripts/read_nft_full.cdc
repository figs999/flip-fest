import ExampleNFT from 0xf8d6e0586b0a20c7
import NonFungibleToken from 0xf8d6e0586b0a20c7
import MetaDataUtil from 0xf8d6e0586b0a20c7

pub fun main(): [MetaDataUtil.MetaData] {
  let collection = getAccount(0xf8d6e0586b0a20c7).getCapability<&{NonFungibleToken.CollectionPublic}>(/public/NFTCollection).borrow()!
  return collection.borrowNFT(id: 0).metadata!.getFullMetaData()
}
