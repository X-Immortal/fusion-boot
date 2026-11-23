using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Management;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

namespace DragonLauncher
{
    internal static class DreamSkinIntegration
    {
        private static bool SamePath(string left,string right)
        {
            return !String.IsNullOrWhiteSpace(left)&&!String.IsNullOrWhiteSpace(right)&&
                String.Equals(left.TrimEnd('\\','/'),right.TrimEnd('\\','/'),StringComparison.OrdinalIgnoreCase);
        }

        internal static bool CommandLineHasProfile(string commandLine,string profile)
        {
            if(String.IsNullOrWhiteSpace(commandLine))return false;
            Match match=Regex.Match(commandLine,@"(?:^|\s)--user-data-dir=(?:""([^""]+)""|(\S+))",RegexOptions.IgnoreCase);
            return match.Success&&SamePath(match.Groups[1].Success?match.Groups[1].Value:match.Groups[2].Value,profile);
        }

        private static Dictionary<string,object> ReadState(Settings settings)
        {
            try {
                var state=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(settings.DreamSkinStatePath));
                return Convert.ToInt32(state["port"])==settings.DreamSkinPort&&
                    SamePath(state["profilePath"] as string,settings.DreamSkinProfilePath)&&
                    !String.IsNullOrWhiteSpace(state["browserId"] as string)&&
                    !String.IsNullOrWhiteSpace(state["codexExe"] as string)?state:null;
            }catch{return null;}
        }

        internal static bool MatchesManagedClient(uint pid,string actualExe,Settings settings)
        {
            if(settings==null||!settings.DreamSkinEnabled||pid==0)return false;
            var state=ReadState(settings);
            if(state==null||!SamePath(actualExe,state["codexExe"] as string))return false;
            try {
                using(var search=new ManagementObjectSearcher("SELECT CommandLine FROM Win32_Process WHERE ProcessId="+pid))
                foreach(ManagementObject process in search.Get())
                    using(process)return CommandLineHasProfile(process["CommandLine"] as string,settings.DreamSkinProfilePath);
            }catch{}
            return false;
        }

        private static Dictionary<string,object> Object(object value){return value as Dictionary<string,object>;}
        private static object Field(Dictionary<string,object> data,string name)
        {object value;return data!=null&&data.TryGetValue(name,out value)?value:null;}
        private static bool True(Dictionary<string,object> data,string name)
        {return Field(data,name) is bool&&(bool)Field(data,name);}

        internal static bool ReportReady(string output,Settings settings)
        {
            try {
                if(ReadState(settings)==null)return false;
                var report=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(output);
                var targets=Field(report,"targets") as IEnumerable;
                if(targets==null)return false;
                foreach(object target in targets){
                    var result=Object(Field(Object(target),"result"));
                    var readiness=Object(Field(result,"readiness"));
                    var overflow=Object(Field(result,"documentOverflow"));
                    string theme=Field(result,"themeId") as string;
                    string expected=Field(result,"expectedThemeId") as string;
                    if(True(result,"installed")&&True(result,"stylePresent")&&
                        True(readiness,"windowPass")&&True(readiness,"viewportPass")&&True(readiness,"structurePass")&&
                        !String.IsNullOrWhiteSpace(theme)&&String.Equals(theme,expected,StringComparison.Ordinal)&&
                        Convert.ToInt32(Field(result,"businessClassPollution"))==0&&!True(overflow,"x"))return true;
                }
            }catch{}
            return false;
        }

        internal static bool VerifyTheme(Settings settings,Action<string> log=null)
        {
            if(settings==null||!settings.DreamSkinEnabled)return false;
            var state=ReadState(settings);
            string node=Field(state,"nodePath") as string;
            string injector=Field(state,"injectorPath") as string;
            string theme=Field(state,"themeDir") as string;
            string browser=Field(state,"browserId") as string;
            Guid browserId=Guid.Empty;
            bool direct=!String.IsNullOrWhiteSpace(node)&&!String.IsNullOrWhiteSpace(injector)&&
                !String.IsNullOrWhiteSpace(theme)&&node.IndexOf('"')<0&&injector.IndexOf('"')<0&&theme.IndexOf('"')<0&&
                Guid.TryParse(browser,out browserId)&&File.Exists(node)&&File.Exists(injector)&&Directory.Exists(theme);
            if(!direct&&!File.Exists(settings.DreamSkinVerifyScript)){
                if(log!=null)log("Dream Skin verifier unavailable");return false;
            }
            string executable=direct?node:Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                "WindowsPowerShell","v1.0","powershell.exe");
            string arguments=direct?"\""+injector+"\" --verify --port "+settings.DreamSkinPort+
                " --browser-id "+browserId.ToString("D")+" --theme-dir \""+theme+"\" --timeout-ms 5000":
                "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File \""+
                settings.DreamSkinVerifyScript+"\" -Port "+settings.DreamSkinPort;
            var start=new ProcessStartInfo(executable,arguments){
                UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden,
                RedirectStandardOutput=true,RedirectStandardError=true,
                WorkingDirectory=direct?Path.GetDirectoryName(injector):Path.GetDirectoryName(settings.DreamSkinVerifyScript)
            };
            try {
                using(var process=Process.Start(start)){
                    if(process==null)return false;
                    var output=process.StandardOutput.ReadToEndAsync();
                    var error=process.StandardError.ReadToEndAsync();
                    if(!process.WaitForExit(direct?12000:40000)){
                        if(log!=null)log("Dream Skin verifier timed out");return false;
                    }
                    error.Wait(1000);
                    string report=output.GetAwaiter().GetResult();
                    bool ready=ReportReady(report,settings);
                    if(log!=null)log("Dream Skin verifier mode="+(direct?"local-read-only":"script")+
                        "; exit="+process.ExitCode+"; bytes="+report.Length+"; rendered="+ready);
                    return ready;
                }
            }catch(Exception failure){if(log!=null)log("Dream Skin verifier error="+failure.GetType().Name);return false;}
        }
    }
}
