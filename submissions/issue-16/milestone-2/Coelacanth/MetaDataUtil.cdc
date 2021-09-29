/*
	This project is addressing problem "New Standard: NFT metadata #16"
	The below code is untested and is meant as an illustration of the concept.
	
	MetaDataUtil, MIME, and CommonMetaDataElements are added as a new default contracts.
	
	Metadata is instantiated in the form of structs at the time the NFT is minted.
	Metadata is organized by string tags, and each metadata element may have multiple tags allowing NFTs to conform to multiple tag schemas.
	Metadata elements cannot be added after the NFT is minted, but Mutable elements can allow data to be modifiable.
	
	MetaDataElements are wrappers around two possible types of structs, one of which is immutable and the other of which is Mutable.
	MetaDataElements possess 3 accessible functions that access stored properties 
		The getData function can return an object of any AnyStruct type, and contains the actual metadata itself
		The getDataType function returns a DataType object that describes the MIME type of the object for reference by off-chain systems
			MIME type is used as it is a widely used standard that can already be understood by browsers
			DataTypes also contain isLink, which is true if the data element describes a link to externaly hosted data.
			innerMIME is used to describe the final data type if the data blob should be decompressed or downloaded by the client 
	Immutable elements can use default types or be defined in custom structs that implement ITaggedMetaData and IImmutableMetaData. 
		Defining a custom class allows the data elements to be immutable while allowing a developer to upgrade the contract that defines the struct to alter the tags.
	Mutable elements store Capability pointers to IMetaDataProvider instances that can be stored anywhere.
		Mutable elements can be used for metadata that can be modified, such as for leveling up a character.
		Mutable elements can also be used for metadata that is shared between multiple NFTs, to minimize redundant data storage.
			A Side-effect (benefit?) here is that if the instance is stored in a contract in the developers account, the developer will need to cover the metaData storage costs instead of the NFT holder.
			PNG_RemoteDefaultImage is a default implementation that can be used to give an NFT a shared and/or updatable image.
				RemotePNGProvider is an example of an implementation of IMetaDataProvider that allows multiple NFTs to share the same image via Capability reference.

	MIME contains a number of commonly used DataTypes for convenience
	CommonMetaDataElements contains default struct implementations that can be wrapped by MetaDataElements
		More default struct implementations should be added for any other common use cases

    Schema, SchemaElement, and SchemaRetrievalMode are data types primarily for off-chain accessing of MetaData, although it may be useful for certain on-chain functionality
        MetaDataHolder.retrieveSchemaData can be used to retrieve solid copies of the NFTs metadata for use off-chain via script
        SchemaRetrievalMode allows the caller to require varying degrees of schema compliance
        If the Schema complies, MetaDataHolder.retrieveSchemaData returns a Schema object which contains the MetaData in its elements[?].schemaData properties
        If compliance fails, the method returns nil
*/

pub contract MetaDataUtil {
    //Utilizing MIME types as existing standard, this will allow metadata to be more easily parsed by a browser
    //Any struct type that conforms to the HasMetaData interface must use MIME type "application/flow+Schema"
    //Any other non-conformant type should use a MIME type with the following syntax "application/flow+T" where T is the Type.
    pub struct DataType {
        //This should be an IANA MIME type
        pub let MIME : String
        //Is the data a link to a file on an external service (ipfs for instance)
        pub let isLink : Bool
        //if the data is compressed or a link, this IAMA MIME type of the actual final data (after download/decompression)
        pub let innerMIME : String?

        init(MIME : String, isLink : Bool, innerMIME : String?)  {
            self.MIME = MIME
            self.isLink = isLink
            self.innerMIME = innerMIME
        }
    }

    //Interface for Partial MetaDataElement implementation.
    pub struct interface ITaggedMetaData {
        pub fun getTags() : [String]
        pub let id: UInt64
    }

    pub struct interface IMetaDataProvider {
        pub fun getData(id: UInt64) : AnyStruct
        pub fun getDataType(id: UInt64) : DataType
        pub fun getTags(id: UInt64) : [String]
    }

    pub struct interface IImmutableMetaData {
        pub let data: AnyStruct
        pub let type: DataType
    }

    pub struct interface IMutableMetaData {
        pub let dataProvider: Capability<&{IMetaDataProvider}>
    }
    
    // Interface that the NFTs have to conform to
    //
    pub struct interface HasMetaData {
        pub let metadata: MetaDataUtil.MetaDataHolder?
    }

    //Solid version of MetaDataHolder that can be passed around or returned in script call for use off-chain
    pub struct MetaData {
        pub let data : AnyStruct
        pub let tags : [String]
        pub let type : DataType
        pub let mutable : Bool

        init(data : AnyStruct, type : DataType, tags : [String], mutable : Bool) {
            self.data = data
            self.type = type
            self.tags = tags
            self.mutable = mutable
        }
    }

    pub struct SchemaElement {
        pub let requiredTags : [String]
        pub let validMIMETypes : [String]
        pub let schemaData : [MetaData]
        pub let subSchema: Schema?
        init(requiredTags : [String], validMIMETypes : [String], subSchema: Schema?) {
            self.requiredTags = requiredTags
            self.validMIMETypes = validMIMETypes
            self.schemaData = []
            self.subSchema = subSchema
        }
    }

    pub struct Schema {
        pub let elements : [SchemaElement]
        init(elements : [SchemaElement]) {
            self.elements = elements
        }
    }

    pub enum SchemaRetrievalMode : UInt8 {
        //Schema always is returned, even if empty
        pub case ALLOW_NONE
        //Schema is returned if any MetaData is found
        pub case REQUIRE_ANY
        //Schema is returned only if all SchemaElements are found
        pub case REQUIRE_ALL
        //Schema is returned if any MetaData is found, but only if each SchemaElement has 1 or less matches
        pub case SINGLE_DATA_ANY
        //Schema is only returned if exactly one MetaData is found per SchemaElement
        pub case SINGLE_DATA_ALL
    }

    pub struct MetaDataHolder {
        access(self) let elements : [MetaDataElement]

        init(metaData : [MetaDataElement]?) {
            self.elements = metaData ?? []
        }

        pub fun getFullMetaData() : [MetaData] {
            var elements : [MetaData] = []
            for element in self.elements {
                elements.append(element.toMetaData(subSchema: nil))
            }
            return elements
        }

        pub fun getFullSchema() : Schema {
            let elements : [SchemaElement] = []
            
            for element in self.getFullMetaData() {
                let schemaElement = SchemaElement(
                    requiredTags: element.tags,
                    validMIMETypes : [element.type.MIME], 
                    subSchema: nil
                )
                schemaElement.schemaData.append(element)
                elements.append(schemaElement)
            }

            return Schema(elements: elements)
        }

        pub fun getMetaDatasByTag(tag : String) : [MetaData] {
            var taggedElements : [MetaData] = []
            for element in self.elements {
                if (element.hasTag(tag : tag)) {
                    taggedElements.append(element.toMetaData(subSchema: nil))
                }
            }
            return taggedElements
        }

        pub fun getMetaDatasBySchemaElement(schemaElement: SchemaElement) : [MetaData] {
            let matchingElements : [MetaData] = []
            for element in self.elements {
                if(element.hasAllTags(requiredTags: schemaElement.requiredTags) && element.conformsToTypeRequirements(validMIMETypes: schemaElement.validMIMETypes)) {
                    matchingElements.append(element.toMetaData(subSchema: schemaElement.subSchema))
                }
            }

            return matchingElements
        }

        //When successfull, this method returns the schema object with the MetaData filled into the SchemeElements
        //If the NFTs metadata does not conform to the schema with the chosen SchemaRetrievalMode, it returns nil
        //Checking the return of this method to see if it is nil can be used to check if the NFT conforms to the required Schema
        pub fun retrieveSchemaData(schema : Schema, retrievalMode : SchemaRetrievalMode) : Schema? {
            var foundAll = true
            var foundAny = false
            var allSingle = true
            for schemaElement in schema.elements {
                let found = self.getMetaDatasBySchemaElement(schemaElement: schemaElement)
                schemaElement.schemaData.appendAll(found)

                if(found.length > 0) {
                    foundAny = true
                    if(found.length > 1) {
                        allSingle = false
                    }
                } else {
                    foundAll = false
                }
            }

            switch retrievalMode {
                case SchemaRetrievalMode.SINGLE_DATA_ALL:
                    if(!foundAll && !allSingle) {
                        return nil
                    }
                case SchemaRetrievalMode.SINGLE_DATA_ANY:
                    if(!foundAny && !allSingle) {
                        return nil
                    }
                case SchemaRetrievalMode.REQUIRE_ALL:
                    if(!foundAll) {
                        return nil
                    }
                case SchemaRetrievalMode.REQUIRE_ANY:
                    if(!foundAll) {
                        return nil
                    }
                default:
                    break
            }

            return schema
        }
    }

    //Struct wrapper around metadata implemenations.
    //Because this struct is defined in default contract, users can rest assured that the code that accesses their metadata cannot be altered.
    pub struct MetaDataElement {
        pub let metaData : {ITaggedMetaData}

        init (metadata : {ITaggedMetaData}) {
            //This forces metadata to conform to expected implementations of "ITaggedMetaData,IMutableMetaData" or "ITaggedMetaData,IImmutableMetaData"
            if (!metadata.isInstance(Type<{IMutableMetaData}>()) && !metadata.isInstance(Type<{IImmutableMetaData}>())) {
                panic("Invalid Metadata Type")
            }
            self.metaData = metadata
        }

        pub fun getData() : AnyStruct {
            let m1 = self.metaData as? {IMutableMetaData}
            if(m1 != nil) {
                return m1!.dataProvider.borrow()!.getData(id: self.metaData.id)
            }
            //Immutable data directly references storage via default contract code, ensuring it cannot be altered by contract upgrade
            let m2 = self.metaData as? AnyStruct{IImmutableMetaData}
            if(m2 != nil) {
                return m2!.data
            }

            //this cannot be reached
            panic("Invalid MetaData")
        }

        pub fun getDataType() : DataType {
            let m1 = self.metaData as? {IMutableMetaData}
            if(m1 != nil) {
                return m1!.dataProvider.borrow()!.getDataType(id: self.metaData.id)
            }
            //Immutable data directly references storage via default contract code, ensuring it cannot be altered by contract upgrade
            let m2 = self.metaData as? AnyStruct{IImmutableMetaData}
            if(m2 != nil) {
                return m2!.type
            }

            //this cannot be reached
            panic("Invalid MetaData")
        }

        pub fun getTags() : [String] {
            //ITaggedMetaData relies on function to return tags for both immutable and mutable. This allows contract upgrades to effect tags.
            return self.metaData.getTags()
        }

        pub fun hasTag(tag : String) : Bool {
            return self.metaData.getTags().contains(tag)
        }

        pub fun hasAllTags(requiredTags : [String]) : Bool {
            let tags : [String] = self.metaData.getTags()
            for tag in requiredTags {
                if(!tags.contains(tag)) {
                    return false
                }
            }

            return true
        }

        pub fun conformsToTypeRequirements(validMIMETypes : [String]) : Bool {
            if(validMIMETypes.length == 0) {
                return true
            }
            let dataType = self.getDataType()
            let mime = dataType.innerMIME ?? dataType.MIME
            for type in validMIMETypes {
                if(type == mime) {
                    return true
                }
            }
            return false
        }

        pub fun toMetaData(subSchema: Schema?) : MetaData {
            var dataType = self.getDataType()
            var data = self.getData()
            var subData = data as? {HasMetaData}
            if(subData != nil && subData!.metadata != nil) {
                dataType = DataType(MIME: "application.flow+Schema", isLink: false, innerMIME: nil)
                if(subSchema == nil) {
                    data = subData!.metadata!.getFullSchema()
                } else {
                    data = subData!.metadata!.retrieveSchemaData(schema: subSchema!, retrievalMode: SchemaRetrievalMode.ALLOW_NONE)
                }
            }
            return MetaData(data: self.getData(), type: dataType, tags: self.getTags(), mutable: self.isMutable())
        }

        //This method can be checked to determine if the associated metadata is able to be altered by developers
        pub fun isMutable() : Bool {
            return self.metaData.isInstance(Type<AnyStruct{IMutableMetaData}>())
        }
    }
}