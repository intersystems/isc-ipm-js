# isc.ipm.js User Guide <!-- omit in toc -->

- [Prerequisites](#prerequisites)
- [Overview](#overview)
- [Notes on Conventions](#notes-on-conventions)
- [Angular Build Process Automation](#angular-build-process-automation)
- [Web application for Angular Path Location Strategy](#web-application-for-angular-path-location-strategy)
- [OpenAPI-based client code generation](#openapi-based-client-code-generation)

## Prerequisites

isc.ipm.js requires InterSystems IRIS Data Platform 2018.1 or later.

Installation is done via the [Community Package Manager](https://github.com/intersystems-community/zpm):

    zpm "install isc.ipm.js"

## Overview

isc.ipm.js enables modern web application development, deployment, and packaging for applications built on InterSystems IRIS and using the InterSystems Package Manager. Our pilot use case is Angular, but we would love to collaborate with the community to build out similar features for other tools.

There are three parts to this:
* Angular build process automation within the package lifecycle
* Web application handling for Angular's path location strategy
* Generation of client code from OpenAPI specifications, which [isc.rest](https://github.com/intersystems/isc-rest) can generate easily

For a simple example of all of these things working together, see [isc.perf.ui](https://github.com/intersystems/isc-perf-ui) and particularly its [module.xml](https://github.com/intersystems/isc-perf-ui/blob/main/module.xml)

## Notes on Conventions

By convention we put Angular applications in an "ng" subdirectory relative to the package root, and normally the built UI will end up in dist/app-name, where app-name is your application's npm package name. Given an Angular application named "app-name" the folder structure will be:

```
/ng
    /app-name
        /node_modules
        /dist
            app-name
                *.js
                *.css
                index.html
        /src
        angular.json
        package.json
        package-lock.json
```

Automated build processes in this tool run npm ci for predictability and repeatability, and this requires package-lock.json. As such, package-lock.json must be committed to source control and treated as code. 

## Angular Build Process Automation

isc.ipm.js will automatically run `npm ci` and `ng build` on your Angular UI as part of the InterSystems package manager lifecycle. Note that this requires an appropriate node and npm version to be installed for your target Angular version.

In module.xml, define a resource pointing to your Angular application root with ProcessorClass set to pkg.isc.ipm.js.angular.processor:
```
<Resource Name="/ng/app-name" ProcessorClass="pkg.isc.ipm.js.angular.processor">
    <Attribute Name="baseHref">/csp/${namespace}/app-name</Attribute>
</Resource>
```

After the build completes, the hash of package.json and package-lock.json are stored, and npm ci will not run again unless those change (or you indicate that install should be forced).

The angular build process accepts two flags (in relevant zpm module lifecycle commands) to control its behavior:
* `-DAngular.NoBuild=1` will suppress the npm install and Angular build (useful, for example, to load in updates to classes only)
* `-DAngular.ForceInstall=1` will force running `npm ci` even if it seems unnecessary (that is, package.json and package-lock.json are unchanged)

When you package your solution (e.g., via `zpm "your-app publish"`) the *built* Angular UI will be included, so the build will not need to run for clients downloading your package from a registry (e.g., using [zpm-registry](https://openexchange.intersystems.com/package/zpm-registry)).

## Web application for Angular Path Location Strategy

To make URLs prettier and simpler for users, Angular applications may - and really should - use the ["Path Location Strategy"](https://angular.io/api/common/PathLocationStrategy). Normally this [requires some additional webserver configuration](https://www.learninjava.com/angular-router-config-apache-nginx-tomcat/). isc.ipm.js provides a CSP-based alternative to that webserver configuration.

To use it, add a resource in module.xml using the package manager's built-in CSPApplication processor and targeting the location of your built Angular UI (e.g., /ng/app-name/dist/app-name). This application should have `DispatchClass` set to `pkg.isc.ipm.js.angular.pathLocationHandler` *and* a `Directory` defined.

For example:
```
<Resource Name="/ng/app-name/dist/app-name" ProcessorClass="CSPApplication" Generated="true">
    <Attribute Name="DispatchClass">pkg.isc.ipm.js.angular.pathLocationHandler</Attribute>
    <Attribute Name="Directory">${cspdir}${namespace}/app-name</Attribute>
    <Attribute Name="Url">/csp/${namespace}/app-name</Attribute>
    <Attribute Name="ServeFiles">1</Attribute>
    <Attribute Name="Recurse">1</Attribute>
    <Attribute Name="ServeFilesTimeout">0</Attribute>
</Resource>
```

Under the hood, `pkg.isc.ipm.js.angular.pathLocationHandler` is a simple `%CSP.REST` subclass that returns either a requested asset (.js, .css, image, etc.) or otherwise index.html. This provides an equivalent to web server configuration otherwise needed to serve an Angular UI that uses the path location strategy.

## OpenAPI-based client code generation

[isc.rest](https://github.com/intersystems/isc-rest) can generate OpenAPI specs for APIs defined using it. isc.ipm.js provides the glue between isc.rest and [openapi-generator](https://openapi-generator.tech/), a popular open source tool that provides support for a wide variety of clients.

Again focusing on the Angular use case, this can be used to generate a file (say, openapi.json) and then process it using openapi-generator to generate Angular services for accessing the REST API and models repesenting the types it returns and accepts.

For example:
```
<Resource Name="/api/openapi.json" ProcessorClass="pkg.isc.ipm.js.openApiProcessor">
    <Attribute Name="DispatchClass">myapp.rest.Handler</Attribute>
    <Attribute Name="Url">/csp/${namespace}/my-app/api</Attribute>
    <Attribute Name="BaseUrl">/api</Attribute>
    <Attribute Name="TargetFolder">/ng/my-app/src/app/generated</Attribute>
    <Attribute Name="Generator">typescript-angular</Attribute>
    <Attribute Name="AdditionalProperties">paramNaming=original,queryParamObjectFormat=key,useSingleRequestParameter=true,ngVersion=13.3.4</Attribute>
</Resource>
```

Where:
* `DispatchClass` is the name of your `%pkg.isc.rest.handler` subclass
* `Url` is the web application path through which that REST handler is being served
* `BaseUrl` is the URL to use as the base endpoint for accessing the API; in this case, a relative path (`/api`) is used because the Angular application lives in `/csp/${namespace}/my-app`
* `TargetFolder` is the place in your Angular application where code will be generated
* `Generator` is one of the *very* many generators supported by openapi-generator [(see the full list)](https://openapi-generator.tech/docs/generators)
* `AdditionalProperties` vary per generator and are defined in that generator's documentation [(see those for angular-typescript, for example)](https://openapi-generator.tech/docs/generators/typescript-angular)

Also, add the following in your module.xml (within the `<Module>` element):
```
<LifecycleClass>pkg.isc.ipm.js.openApiModule</LifecycleClass>
```

Then, to generate client code for your rest API, it's just a matter of running:
```
zpm "my-app generate"
```