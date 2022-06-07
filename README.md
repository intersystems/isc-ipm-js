# isc.ipm.js
isc.ipm.js enables modern web application development, deployment, and packaging for applications built on InterSystems IRIS and using the InterSystems Package Manager. Our pilot use case is Angular, but we would love to collaborate with the community to build out similar features for other technologies.

There are three parts to this:
* Angular build process automation within the package lifecycle
* Web application handling for Angular's path location strategy
* Generation of client code from OpenAPI specifications, which [isc.rest](https://github.com/intersystems/isc-rest) can generate easily

For a simple example of all of these things working together, see [isc.perf.ui](https://github.com/intersystems/isc-perf-ui) and particularly its [module.xml](https://github.com/intersystems/isc-perf-ui/blob/main/module.xml)

## Getting Started
Note: a minimum platform version of InterSystems IRIS 2018.1 is required.

### Installation: ZPM

If you already have the [ObjectScript Package Manager](https://openexchange.intersystems.com/package/ObjectScript-Package-Manager-2), installation is as easy as:
```
zpm "install isc.ipm.js"
```

## User Guide
See [isc.ipm.js User Guide](https://github.com/intersystems/isc-ipm-js/blob/master/docs/user-guide.md).

## Support
If you find a bug or would like to request an enhancement, [report an issue](https://github.com/intersystems/isc-ipm-js/issues/new). If you have a question, feel free to post it on the [InterSystems Developer Community](https://community.intersystems.com/).

## Contributing
Please read [contributing](https://github.com/intersystems/isc-ipm-js/blob/master/CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning
We use [SemVer](http://semver.org/) for versioning. Declare your dependencies using the InterSystems package manager for the appropriate level of risk.

## Authors
* **Tim Leavitt** - *Initial implementation* - [isc-tleavitt](http://github.com/isc-tleavitt)

See also the list of [contributors](https://github.com/intersystems/isc-json/graphs/contributors) who participated in this project.

## License
This project is licensed under the MIT License - see the [LICENSE](https://github.com/intersystems/isc-json/blob/master/LICENSE) file for details.
