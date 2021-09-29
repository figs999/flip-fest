import MetaDataUtil from 0xf8d6e0586b0a20c7

pub contract MIME {
    pub let TextPlain : MetaDataUtil.DataType
    pub let LinkedPNG : MetaDataUtil.DataType
    pub let ImagePNG : MetaDataUtil.DataType
    pub let HasMetaData : MetaDataUtil.DataType
    pub let Numeric : MetaDataUtil.DataType
    pub let AnyStruct : MetaDataUtil.DataType

    init() {
        self.TextPlain = MetaDataUtil.DataType("text/plain",false,nil)
        self.LinkedPNG = MetaDataUtil.DataType("text/plain",true,"image/png")
        self.ImagePNG = MetaDataUtil.DataType("image/png",false,nil)
        //Not an official MIME type, but must be used for any struct that conforms to HasMetaData interface.
        self.HasMetaData = MetaDataUtil.DataType("application/flow+Schema",false,nil)
        //Not an official MIME type, but can be used for numeric data that will be returned in cadence object format
        self.Numeric = MetaDataUtil.DataType("application/flow+Number",false,nil)
        //Not an official MIME type, but can be used for arbitrary data that will be returned in cadence object format
        self.AnyStruct = MetaDataUtil.DataType("application/flow+AnyStruct",false,nil)
    }
}