# Contributing

When contributing to this repository, please first discuss the change you wish to make via issue,
email, or any other method with the owners of this repository before making a change.

# Process

Want to contribute? It's  easy. Fork the repo, make your changes, submit a pull request to the dev branch. Great for a one time change or update or bug fix. Want to contribute more regularly? That's even better. Ask Tim Chapman to join the project as a contributor and then you may create your own branches and submit pull requests directly without a seperate fork. Either way is cool.

# Setup & Tooling

Really all you need is the pre-reqs in the [README](README.md) setup on your workstation and the following:

* [Visual Studio Code](https://code.visualstudio.com/)
* [Git for Windows](https://git-scm.com/download/win)
* [Git Credential Manager for Windows](https://github.com/Microsoft/Git-Credential-Manager-for-Windows)

Pro-tip. Make sure Git is added to your PATH otherwise you'll have lots of long file paths in your setup.

```
C:\Program Files\Git\bin\git.exe
C:\Program Files\Git\cmd
```

# Local Development

So this is really cool and all but I just want to develop against my local repo. I have SQLAnalyzer installed but it's loaded the version I have from your awesome private PSRepostory so what gives!?!

To override and load a local copy of the code for local development just take advantage of PowerShell's direct load syntax by providing a path. For example assuming you clone the repo as shown below you can load the local code:

```
cd C:\Users\<user>\source\repos\SQLAnalyzer
Import-Module -name C:\Users\<user>\source\repos\SQLAnalyzer\SqlAnalyzer.psd1 -force
```
Or if you just want to local the scripting module directly (not common)
```
Import-Module -name C:\Users\<user>\source\repos\SQLAnalyzer\SqlAnalyzer.psm1 -force
```

# Update Version Number

Fire up a PowerShell command prompt and cd to the root of the repository. That probably looks something like this depending on where you cloned:
```
C:\Users\<user>\source\repos\SQLAnalyzer\SQLAnalyzer
```
Next just run PS C:\Users\SomeUser>.\Deploy.ps1 and this script will update the version number by adding 1 to the build number in both the .nuspec and the PowerShell module manifest. Next either commit your changes and submit a PR to the dev branch or if you are already working on the dev brand push your changes. Azure DevOps is set for continous integration and it will take your changes, package up the module, and push the update to the private feed.

# NuGet .nuspec Creation

If you don't like it suggest a better packaging setup. To generate a new NuGet nuspec from this command and if you need NuGet you can download it [from here](https://www.nuget.org/downloads).

```
C:\users\<users>\nuget.exe spec C:\Users\<user>\source\repos\SQLAnalyzer\SQLAnalyzer
```