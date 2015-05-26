﻿namespace CsLuaCompiler
{
    using System;
    using System.CodeDom.Compiler;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.IO;
    using System.Linq;
    using System.Text.RegularExpressions;
    using CsLuaCompiler.Providers;
    using Microsoft.CodeAnalysis;
    using SyntaxAnalysis;

    internal class CsProject
    {
        private const string RawLuaFileHeader =
            "-- This file have been copied from the C# project. Do not edit this file.";

        private const string CsLuaFileHeader = "-- This file have generated from a C# namespace. Do not edit this file.";

        public readonly Dictionary<string, object> Settings;
        private readonly Compilation compilation;
        private readonly IProviders providers;
        private readonly Dictionary<string, NameSpace> nameSpaces;
        public readonly Project CodeProject;
        public string Name;

        public CsProject(IProviders providers, Project project)
        {
            this.Settings = SettingsReader.GetSettings(project);
            this.providers = providers;
            this.CodeProject = project;
            this.compilation = project.GetCompilationAsync().Result;
            if (this.IsCsLuaAddOn())
            {
                if (Debugger.IsAttached)
                {
                    this.nameSpaces = GetNameSpaces(project);
                }
                else
                {
                    try
                    {
                        this.nameSpaces = GetNameSpaces(project);
                    }
                    catch (Exception ex)
                    {

                        throw new WrappingException(string.Format("In project: {0}.", project.Name), ex);
                    }    
                }                                
            }
            this.Name = this.CodeProject.Name;
        }

        public bool IsCsLuaAddOn()
        {
            return this.Settings.ContainsKey("Interface");
        }

        public string GetProjectPath()
        {
            var projectFile = new FileInfo(this.CodeProject.FilePath);
            return projectFile.Directory.FullName;
        }

        public bool IsLuaAddOn()
        {
            var fileInfo = new FileInfo(this.GetProjectPath() + "\\" + this.CodeProject.Name + ".toc");
            return fileInfo.Exists;
        }

        public IEnumerable<string> GetReferences()
        {
            return this.compilation.References.Select(_ref => _ref.Display)
                .Where(name => !name.Contains("\\Reference Assemblies\\"));
        }

        public IEnumerable<CodeFile> GetLuaFiles()
        {
            var files = new List<CodeFile>();

            if (this.nameSpaces != null)
            {
                foreach (var nameSpacePair in this.nameSpaces)
                {
                    var textWriter = new StringWriter();
                    nameSpacePair.Value.WriteLua(new IndentedTextWriter(textWriter), this.providers);
                    files.Add(new CodeFile
                    {
                        FileName = nameSpacePair.Key + ".lua",
                        Content = textWriter.ToString(),
                        Header = CsLuaFileHeader
                    });
                }
            }

            string projectPath = Path.GetDirectoryName(this.CodeProject.FilePath);
            string[] luaFiles = Directory.GetFiles(projectPath, "*.lua", SearchOption.AllDirectories);

            foreach (string luaDoc in luaFiles)
            {
                files.Add(new CodeFile
                {
                    FileName = Path.GetFileName(luaDoc),
                    Content = File.ReadAllText(luaDoc),
                    Header = RawLuaFileHeader
                });
            }

            var additionalFiles = new List<CodeFile>();
            files.ForEach(file =>
            {
                Match match = Regex.Match(file.Content, @"^--TargetFile: *(\w*\.lua)");
                if (match.Success)
                {
                    string targetfileName = match.Groups[1].Value;
                    CodeFile targetFile =
                        files.FirstOrDefault(otherFile => otherFile.FileName.Equals(targetfileName)) ??
                        additionalFiles.FirstOrDefault(otherFile => otherFile.FileName.Equals(targetfileName));
                    if (targetFile == null)
                    {
                        targetFile = new CodeFile {FileName = targetfileName, Content = file.Content};
                        additionalFiles.Add(targetFile);
                    }
                    else
                    {
                        targetFile.Content += "\n" + file.Content;
                    }
                    file.Ignore = true;
                }
            });
            files.AddRange(additionalFiles);
            return files.Where(file => file.Ignore != true);
        }

        private static Dictionary<string, NameSpace> GetNameSpaces(Project project)
        {
            IEnumerable<Document> docs = project.Documents
                .Where(doc => doc.Folders.FirstOrDefault() != "Properties"
                              && !doc.FilePath.EndsWith("AssemblyAttributes.cs")
                );

            var nameSpaces = new Dictionary<string, NameSpace>();
            foreach (Document document in docs)
            {
                NameSpacePart nameSpacePart = new SyntaxAnalyser().AnalyseDocument(document);
                if (nameSpaces.ContainsKey(nameSpacePart.FullName.First()))
                {
                    nameSpaces[nameSpacePart.FullName.First()].AddPart(nameSpacePart);
                }
                else
                {
                    nameSpaces[nameSpacePart.FullName.First()] = new NameSpace(nameSpacePart, 1);
                }
            }
            return nameSpaces;
        }
    }
}