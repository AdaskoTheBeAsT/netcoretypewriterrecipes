${
    using Typewriter.Extensions.Types;
    using Typewriter.Extensions.WebApi;
    using System.Text;
    using System.Text.RegularExpressions;

    // setting template
    Template(Settings settings)
    {
        settings.IncludeCurrentProject();

        // file should be named same as controller name with 'Service' suffix
        settings.OutputFilenameFactory = file => $"{file.Classes.First().Name.Replace("Controller", "Service")}.ts";
    }

    // returns type of the method to typescript
    string ReturnType(Method m)
    {
        // check if there is special attribute for response type and take type from there
        var attr = m.Attributes.FirstOrDefault(a => a.Name == "ProducesResponseType");
        if(attr != null){
            // due to limited functionality of attribute value process value by regexp
            var r = new Regex(".*typeof[(]([^.]*[.])*([^)]*)[)].*");
            return r.Replace(attr.Value, "$2");
        }

        // if there is only IActionResult return any as type
        return m.Type.Name == "IActionResult" ? "any" : m.Type.Name;
    }

    // get angular service name based on controller class name
    string ServiceName(Class c) => c.Name.Replace("Controller", "Service");

    // get angular service name based on controller in which given method is defined
    string ParentServiceName(Method m) => ServiceName((Class)m.Parent);

    // get method name
    string MethodName(Method m)
    {
        var methodName = m.Attributes.FirstOrDefault(a => a.Name.StartsWith("CustomName"))?.Value ?? string.Empty;
        if(!string.IsNullOrEmpty(methodName)) {
            return methodName;
        }
        var sb = new StringBuilder(m.name);
        foreach(var par in m.Parameters) {
            sb.Append(NameOfType(par.Type));
        }
        return sb.ToString();
    }

    // returns true if class should be treated as candidate for angular service
    bool IncludeClass(Class c){
        var parent = c.BaseClass;
        if(parent == null){
            return false;
        }

        // all controllers are subclasses of Controller or ControllerBase
        if(parent.Name.EndsWith("Controller") || 
            parent.Name.EndsWith("ControllerBase"))
        {
            return true;
        }

        return false;
    }

    string RemoveNamespace(string s){
        var pos = s.LastIndexOf(".");
       
        return pos ==-1 ? s : s.Substring(pos+1);
    }

    // generates imports in typescript
    // generates imports in typescript
    string Imports(Class c)
    {
        var typeNameList = new List<KeyValuePair<string, bool>>();

        //walk through all the method of controller
        foreach(var method in c.Methods) {
            // generate list of candidates for imports only from non-primitive types
            if(!method.Type.IsPrimitive) {
                // check if method has special ProducesResponseType aattribute and get type from there
                var attr = method.Attributes.FirstOrDefault(a => a.Name == "ProducesResponseType");
                if(attr != null){
                    // due to limited functionality of attribute value process value by regexp
                    // additionally removing [] from the end of the type as imports can be done only on normal class name
                    var r = new Regex(@".*typeof[(]([^.]*[.])*([^)[\]]*)([[][\]])?[)].*");
                    var name = r.Replace(attr.Value, "$2");
                    if(!IsString(name) && !IsDictionary(name)){
                        typeNameList.Add(new KeyValuePair<string, bool>(name, false));
                    }
                }
                else { // if there is no attribute just get type name
                    var name = method.Type.Unwrap().Name;

                    // IActionResult should be skipped
                    if(name != "IActionResult") {
                        if(!IsDictionary(name)){
                            typeNameList.Add(new KeyValuePair<string, bool>(name, false));
                        }
                    }
                }
            }

            // walk through each parameter in method
            foreach(var parameter in method.Parameters)
            {
                // skip if it is primitive
                if(parameter.Type.IsPrimitive){
                    continue;
                }

                var name = parameter.Type.Unwrap().Name;
                if(parameter.Type.IsEnum){
                    typeNameList.Add(new KeyValuePair<string, bool>(name, true));
                }
                else if(!IsDictionary(name)){
                    // add type to list
                    typeNameList.Add(new KeyValuePair<string, bool>(name, false));
                }
            }
        }

        var sb = new StringBuilder();
        foreach(var type in typeNameList.GroupBy(p => p.Key).Select(grp => grp.FirstOrDefault())){
            if(type.Value){
                sb.AppendLine($"import {{ {type.Key} }} from '../models/{type.Key}';");
            }
            else {
                sb.AppendLine($"import {{ I{type.Key}, {type.Key} }} from '../models/{type.Key}';");
            }
        }

        return sb.ToString();
    }

    bool IsString(string str){
        if(str == "string")
        {
            return true;
        }

        return false;
    }

    bool IsPrimitive(Parameter parameter){
        if(parameter.Type == "string")
        {
            return true;
        }

        if(parameter.Type == "number")
        {
            return true;
        }

        if(parameter.Type == "boolean")
        {
            return true;
        }

        return false;
    }


    // gets name of the url field in service
    string UrlFieldName(Class c) => $"{c.name.Replace("Controller", "Service")}Url";

    string HttpGetActionNameByAttribute(Method m){
        return GetActionNameByAttribute(m, "HttpGet");
    }

    string HttpPostActionNameByAttribute(Method m){
        return GetActionNameByAttribute(m, "HttpPost");
    }

    string HttpPutActionNameByAttribute(Method m){
        return GetActionNameByAttribute(m, "HttpPut");
    }

    string HttpDeleteActionNameByAttribute(Method m){
        return GetActionNameByAttribute(m, "HttpDelete");
    }

    string GetActionNameByAttribute(Method m, string name) {    
        var value = m.Attributes.FirstOrDefault(a => a.Name == name)?.Value ?? string.Empty;
        if(!string.IsNullOrEmpty(value) && !value.Contains("{")){
             return "/"+value;
        }else{
            return string.Empty;
        }
    }

    // generates getter implementation for url - only controllers with Attribute Routing are processed
    string GetRouteValue(Class c)
    {
        var route = c.Attributes.Where(a => a.Name == "Route").FirstOrDefault();
        if(route == null)
        {
            return string.Empty;
        }

        const string controllerPlaceholder = "[controller]";
        var routeValue = route.Value;
        if(routeValue.Contains(controllerPlaceholder))
        {
            routeValue = routeValue.Replace(controllerPlaceholder, c.Name.Replace("Controller", string.Empty));
        }

        return routeValue;
    }

    bool IsGetMethod(Method method){
        return method.HttpMethod() == "get";
    }

    bool IsPostMethod(Method method){
        return method.HttpMethod() == "post" && !method.Attributes.Any(a => a.Name == "ProducesResponseType");
    }

    bool IsPostMethodWithResult(Method method){
        return method.HttpMethod() == "post" && method.Attributes.Any(a => a.Name == "ProducesResponseType");
    }

    bool IsPutMethod(Method method){
        return method.HttpMethod() == "put";
    }

    bool IsDeleteMethod(Method method){
        return method.HttpMethod() == "delete";
    }

    string GetParameterValue(Parameter parameter){
        if(parameter.Type == "string"){
            return parameter.name;
        }

        return $"{parameter.name}.toString()";
    }

    bool IsDictionary(Parameter parameter){
        return IsDictionary(parameter.Type);
    }

    bool IsDictionary(string name){
        var r=new Regex(@"[{]\s[[]key:\s[^\]]+[\]]:\s[^;]+;\s[}]");
        return r.Match(name).Success;
    }

    string NameOfType(Type t){
        if(IsDictionary(t.Name)){
            return "Dictionary";
        }
        return t.Name;
    }
}
import { API_BASE_URL } from '../../app-config.module';
import { Inject, Injectable, Optional } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';

import { Observable } from 'rxjs/Observable';
import 'rxjs/add/operator/catch';
import 'rxjs/add/operator/map';

$Classes($IncludeClass)[
$Imports

export interface I$ServiceName {
    $Methods[$MethodName($Parameters[$name: $Type][, ]): Observable<$ReturnType>;
    ]
}

@Injectable()
export class $ServiceName implements I$ServiceName {
    constructor (@Inject(HttpClient) protected http: HttpClient, @Optional() @Inject(API_BASE_URL) protected baseUrl?: string) {
    }

    public get $UrlFieldName(): string {
        if(this.baseUrl) {
            return this.baseUrl.endsWith('/') ? this.baseUrl+'$GetRouteValue' : this.baseUrl+'/'+'$GetRouteValue';
        } else {
            return '$GetRouteValue';
        }
    }
    
    $Methods[
        $IsGetMethod[
    public $name$Parameters[$Type[$NameOfType]]($Parameters[$name: $Type][, ]): Observable<$ReturnType> {
        const headers = new HttpHeaders()
            .set("Accept", "application/json")
            .set("If-Modified-Since", "0");

       let params = new HttpParams();
       let funcObj = {
            addToHttpParams(key: string, elem: any): void {
                if (typeof elem === 'undefined' || elem == null) {
                    return;
                }

                params = params.set(key, elem);
            },
            processObject(key: string, obj: object, firstPass:boolean, itemFunc: (key: string, item: any) => void): void {
                for (let property in obj) {
                    if (!obj.hasOwnProperty(property)){
                        continue;
                    }

                    if (property==='$type') {
                        continue;
                    }
                    let name = firstPass ? property : key + "." + property;
                    this.process(name, obj[property], false, itemFunc);
                }
            },
            processArray(key:string, arr: Array<any>, itemFunc: (key:string, item:any)=>void): void {
                for (let id in arr) {
                    if (!arr.hasOwnProperty(id)){
                        continue;
                    }
                    let itemName = key + '[' + id + ']';
                    let item = arr[id];
                    this.process(itemName, item, false, itemFunc);
                }
            },
            process(key: string, obj: any, firstPass: boolean, itemFunc: (key: string, item: any) => void): void {
                if (obj == null) { 
                    return;
                } 

                if (Array.isArray(obj)) {
                    this.processArray(key, obj, itemFunc);
                }
                else if (typeof obj === 'object') {
                    this.processObject(key, obj, firstPass, itemFunc);
                }
                else { 
                    itemFunc(key, obj);
                }
            }
        };

        let parr = [];

        $Parameters[
        parr.push($name);
        funcObj.process('$name', parr.pop(), true, funcObj.addToHttpParams);]

        return this.http.get<$ReturnType>(
            this.$Parent[$UrlFieldName]+'$HttpGetActionNameByAttribute',
            {
                headers: headers,
                params: params
            });
    }]
    $IsPutMethod[
    public $MethodName($Parameters[$name: $Type][, ]): Observable<$ReturnType> {
        const headers = new HttpHeaders()
            .set("Content-Type", "application/json")
            .set("Accept", "application/json")
            .set("If-Modified-Since", "0");

        return this.http.put(
            this.$Parent[$UrlFieldName]+'$HttpPutActionNameByAttribute',
            $Parameters[$name],
            {
                headers: headers,
                responseType: 'text'
            });
    }]
    $IsPostMethod[
    public $MethodName($Parameters[$name: $Type][, ]): Observable<any> {
        const headers = new HttpHeaders()
            .set("Content-Type", "application/json")
            .set("Accept", "application/json")
            .set("If-Modified-Since", "0");

        return this.http.post(
            this.$Parent[$UrlFieldName]+'$HttpPostActionNameByAttribute',
            $Parameters[$name],
            {
                headers: headers,
                responseType: 'text'
            });
    }]
    $IsPostMethodWithResult[
    public $MethodName($Parameters[$name: $Type][, ]): Observable<$ReturnType> {
        const headers = new HttpHeaders()
            .set("Content-Type", "application/json")
            .set("Accept", "application/json")
            .set("If-Modified-Since", "0");

        return this.http.post<$ReturnType>(
            this.$Parent[$UrlFieldName]+'$HttpPostActionNameByAttribute',
            $Parameters[$name],
            {
                headers: headers
            });
    }]
    $IsDeleteMethod[
    public $MethodName($Parameters[$name: $Type][, ]): Observable<$ReturnType> {
        return this.http.delete<$ReturnType>(
            this.$Parent[$UrlFieldName]+'$HttpPostActionNameByAttribute/'+$Parameters[$name]);
    }]]
}]