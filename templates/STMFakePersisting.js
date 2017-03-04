const methods = [{
    methodName: 'find',
    parameterName: 'identifier',
    parameterType: 'NSString *',
    callbackType: 'Dictionary',
    resultType: 'NSDictionary *'
},{
    methodName: 'findAll',
    parameterName: 'predicate',
    parameterType: 'NSPredicate *',
    callbackType: 'Array',
    resultType: 'NSArray *'
},{
    methodName: 'merge',
    parameterName: 'attributes',
    parameterType: 'NSDictionary *',
    callbackType: 'Dictionary',
    resultType: 'NSDictionary *'
},{
    methodName: 'mergeMany',
    parameterName: 'attributeArray',
    parameterType: 'NSArray *',
    callbackType: 'Array',
    resultType: 'NSArray *'
},{
    methodName: 'destroy',
    parameterName: 'identifier',
    parameterType: 'NSString *',
    callbackType: 'No',
    resultType: 'BOOL',
    isPrimitive: true,
    noResultCallback: true
},{
    methodName: 'destroyAll',
    parameterName: 'predicate',
    parameterType: 'NSPredicate *',
    callbackType: 'Integer',
    resultType: 'NSUInteger',
    isPrimitive: true
},{
    methodName: 'update',
    parameterName: 'attributes',
    parameterType: 'NSDictionary *',
    callbackType: 'Dictionary',
    resultType: 'NSDictionary *'
}];

const meta = {
    date: (new Date()).toUTCString()
};

module.exports = {methods, meta};
