import MetaDataUtil from 0xf8d6e0586b0a20c7
import MIME from 0xf8d6e0586b0a20c7

pub contract CommonMetaDataElements {
    //This implementation allows the tags to also be immutable if required for some reason
    pub struct ImmutablyTaggedData : MetaDataUtil.IImmutableMetaData, MetaDataUtil.ITaggedMetaData {
        pub let data: AnyStruct
        pub let type: MetaDataUtil.DataType
        pub let tags: [String]
        pub let id: UInt64

        init(data : AnyStruct, type: MetaDataUtil.DataType, tags: [String]) {
            self.data = data
            self.type = type
            self.tags = tags
            self.id = 0
        }

        pub fun getTags() : [String] {
            return self.tags
        }
    }

    //Default element implementation that defines the rdf style namespaces used in the NFTs tagging ontology
    //Namespace prefix and uri may not contain white space. URI should be a valid URI of an RDF format namespace definition
    pub struct TagNamespace : MetaDataUtil.IImmutableMetaData, MetaDataUtil.ITaggedMetaData {
        pub let data: AnyStruct
        pub let type: MetaDataUtil.DataType
        pub let id: UInt64

        init(prefix : String, uri: String) {
            self.data = prefix.concat(": ").concat(uri)
            self.type = MIME.TextPlain
            self.id = 0
        }

        pub fun getTags() : [String] {
            return ["TagNamespace", "ns"]
        }
    }

    //Default element implementation that specifies that this NFT uses the common DublinCore /elements/1.1/ tagging ontology 
    pub struct DCNamespace : MetaDataUtil.IImmutableMetaData, MetaDataUtil.ITaggedMetaData {
        pub let data: AnyStruct
        pub let type: MetaDataUtil.DataType
        pub let id: UInt64

        init() {
            self.data = "dc: http://purl.org/dc/elements/1.1/"
            self.type = MIME.TextPlain
            self.id = 0
        }

        pub fun getTags() : [String] {
            return ["TagNamespace", "ns"]
        }
    }

    //Default element implementation for a named NFT, most NFTs will need this
    pub struct DefaultName : MetaDataUtil.IImmutableMetaData, MetaDataUtil.ITaggedMetaData {
        pub let data: AnyStruct
        pub let type: MetaDataUtil.DataType
        pub let id: UInt64

        init(name : String) {
            self.data = name
            self.type = MIME.TextPlain
            self.id = 0
        }

        pub fun getTags() : [String] {
            return ["dc:title", "title", "name"]
        }
    }

    //Default element implementation for an NFT with a text description, most NFTs will need this
    pub struct DefaultDescription : MetaDataUtil.IImmutableMetaData, MetaDataUtil.ITaggedMetaData {
        pub let data: AnyStruct
        pub let type: MetaDataUtil.DataType
        pub let id: UInt64

        init(description : String) {
            self.data = description
            self.type = MIME.TextPlain
            self.id = 0
        }

        pub fun getTags() : [String] {
            return ["dc:description", "description"]
        }
    }

    //Default element implementation for an NFT with unique and immutable binary data that stores a png format image
    pub struct PNG_DefaultImage : MetaDataUtil.IImmutableMetaData, MetaDataUtil.ITaggedMetaData {
        pub let data: AnyStruct
        pub let type: MetaDataUtil.DataType
        pub let id: UInt64

        init(imgData : [UInt8]) {
            self.data = imgData
            self.type = MIME.ImagePNG
            self.id = 0
        }

        pub fun getTags() : [String] {
            return ["dc:source", "image"]
        }
    }

    pub struct UpdatableStats : MetaDataUtil.IMutableMetaData, MetaDataUtil.ITaggedMetaData {
        pub let dataProvider: Capability<&AnyStruct{MetaDataUtil.IMetaDataProvider}>
        pub let id: UInt64
        
        init(id: UInt64, provider : Capability<&UpdatableStatsProvider{MetaDataUtil.IMetaDataProvider}>,) {
            self.dataProvider = provider
            self.id = id
        }

        pub fun getTags() : [String] {
            if(self.dataProvider.borrow() == nil) { panic("no data provider available!") }
            return self.dataProvider.borrow()!.getTags(id: self.id)
        }
    }

    //An instance of this struct is needed for any NFT that utilizes UpdatableStatistics. 
    //A single instance can be shared by multiple resources.
    //As a statistic entry, type of data is assumed to be a number, a string, or a complex struct (Array/Dictionary/Custom)
    //Data can be updated arbitrarily by the account that holds this struct in storage, so this should only be stored in developer controlled account
    pub struct UpdatableStatsProvider : MetaDataUtil.IMetaDataProvider {
        access(self) var data: {UInt64: AnyStruct}
        access(self) var tags: {UInt64: [String]}
        access(self) var type: {UInt64: MetaDataUtil.DataType}

        init () {
            self.data = {}
            self.tags = {}
            self.type = {}
        }

        pub fun addData (id: UInt64, data : AnyStruct, tags : [String]) {
            if(self.data[id] != nil) {
                panic("data already exists for id")
            }

            self.data[id] = data
            self.tags[id] = tags
            self.type[id] = MIME.AnyStruct

            if(data as? Number != nil) {
                self.type[id] = MIME.Numeric
            }
            else if(data as? String != nil) {
                self.type[id] = MIME.TextPlain
            }
        }

        pub fun setData(id: UInt64, data : AnyStruct) {
            if(data.getType() != self.data.getType()) {
                if(data as? Number != nil) {
                    self.type[id] = MIME.Numeric
                }
                else if(data as? String != nil) {
                    self.type[id] = MIME.TextPlain
                }
                else {
                    self.type[id] = MIME.AnyStruct
                }
            }
            
            self.data[id] = data
        }

        //Tags are not static and can be updated
        pub fun setTags(id: UInt64, tags : [String]) {
            self.tags[id] = tags
        }

        pub fun getData(id: UInt64) : AnyStruct {
            return self.data[id]!
        }

        pub fun getDataType(id: UInt64) : MetaDataUtil.DataType { 
            return self.type[id]!
        }

        pub fun getTags(id: UInt64) : [String] {
            return self.tags[id]!
        }
    }

    //Default element implementation for an NFT with mutable or shared binary data that stores a png format image
    pub struct PNG_RemoteDefaultImage : MetaDataUtil.IMutableMetaData, MetaDataUtil.ITaggedMetaData {
        pub let dataProvider: Capability<&AnyStruct{MetaDataUtil.IMetaDataProvider}>
        pub let id: UInt64
        
        init(id: UInt64, provider : Capability<&CommonMetaDataElements.RemotePNGProvider{MetaDataUtil.IMetaDataProvider}>) {
            self.dataProvider = provider
            self.id = id
        }

        pub fun getTags() : [String] {
            if(self.dataProvider.borrow() == nil) { panic("no data provider available!") }
            return self.dataProvider.borrow()!.getTags(id: self.id)
        }
    }

    //An instance of this struct is needed for any NFT that utilizes PNG_RemoteDefaultImage. 
    //A single instance can be shared by multiple resources.
    //This provider allows the data to be either mutable or semi-immutable
    //Data can be updated arbitrarily by the account that holds this struct in storage, so this should only be stored in developer controlled account
    //If needing to store the image in the storage of the resource holder, developers will need to make a custom provider.
    pub struct RemotePNGProvider : MetaDataUtil.IMetaDataProvider {
        access(self) var data: {UInt64: [UInt8]}
        access(self) var isStatic: {UInt64: Bool}

        init() {
            self.data = {}
            self.isStatic = {}
        }

        pub fun addImage (id: UInt64, imgData : [UInt8], static : Bool) {
            if(self.data[id] != nil) {
                panic("")
            }

            self.data[id] = imgData
            self.isStatic[id] = static
        }

        pub fun setImage(id: UInt64, imgData : [UInt8]) {
            if(self.isStatic[id]!) {
                panic("Cannot Set Static Image")
            }
            self.data[id] = imgData
        }

        pub fun getData(id: UInt64) : AnyStruct {
            return self.data
        }

        pub fun getDataType(id: UInt64) : MetaDataUtil.DataType { 
            return MIME.ImagePNG
        }

        pub fun getTags(id: UInt64) : [String] {
            return ["dc:source", "image"]
        }
    }
}