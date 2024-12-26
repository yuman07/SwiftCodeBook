//
//  CodableNote.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/12/26.
//

import Foundation

func testOptionalCodable() {
    struct TestModel1: Codable {
        let values: [Int]
    }
    struct TestModel2: Codable {
        let values: [OptionalCodable<Int>]
    }
    
    let json = "{\"values\":[1,2,\"3\"]}"
    let model1 = TestModel1(JSONString: json)
    let model2 = TestModel2(JSONString: json)
    print(model1 ?? "model1 fail")
    print(model2 ?? "model2 fail")
    print(model2?.toJSONString() ?? "model2 toJSON fail")
}

func testAnyJSONCodable() {
    struct TestModel: Codable {
        let value: AnyJSONCodable
    }
    
    let jsonInt = "{\"value\": 100}"
    let intModel = TestModel(JSONString: jsonInt)
    print(intModel ?? "failed decode int")
    print(intModel?.toJSONString() ?? "failed encode int")
    
    let jsonBool = "{\"value\": true}"
    let boolModel = TestModel(JSONString: jsonBool)
    print(boolModel ?? "failed decode bool")
    print(boolModel?.toJSONString() ?? "failed encode bool")
    
    let jsonDouble = "{\"value\": 3.1415926}"
    let doubleModel = TestModel(JSONString: jsonDouble)
    print(doubleModel ?? "failed decode double")
    print(doubleModel?.toJSONString() ?? "failed encode double")
    
    let jsonString = "{\"value\": \"hello world\"}"
    let stringModel = TestModel(JSONString: jsonString)
    print(stringModel ?? "failed decode string")
    print(stringModel?.toJSONString() ?? "failed encode string")

    let jsonNull = "{\"value\": null}"
    let nullModel = TestModel(JSONString: jsonNull)
    print(nullModel ?? "failed decode null")
    print(nullModel?.toJSONString() ?? "failed encode null")
    
    let jsonArray = "{\"value\":[1,2,\"3\",true,3.14,null, [5,6.89,false,[0, true, null],null]]}"
    let arrayModel = TestModel(JSONString: jsonArray)
    print(arrayModel ?? "failed decode array")
    print(arrayModel?.toJSONString() ?? "failed encode array")
    
    let jsonDict = "{\"value\":{\"key\":123, \"key2\":null, \"key3\": [null, true, 111, { \"key5\":222}]}}"
    let dictModel = TestModel(JSONString: jsonDict)
    print(dictModel ?? "failed decode dict")
    print(dictModel?.toJSONString() ?? "failed encode dict")
}
