﻿namespace CsLuaConverter
{
    using System;
    using System.Collections.Generic;
    using System.IO;
    using System.Linq;
    using System.Text.RegularExpressions;
    using AddOnConstruction;
    using CsLuaSyntaxTranslator;

    static class LuaFileWriter
    {
        private const string RawLuaFileHeader =
            "-- This file have been copied from a C# project.";

        private const string CsLuaFileHeader = "-- This file have generated from a C# namespace.";

        public static IList<CodeFile> GetLuaFiles(IEnumerable<Namespace> nameSpaces, string name, bool requiresCsLuaMetaHeader, string projectPath)
        {
            var files = new List<CodeFile>();

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

            if (nameSpaces != null)
            {
                foreach (var nameSpace in nameSpaces)
                {
                    var textWriter = new StringWriter();
                    nameSpace.WritingAction(new IndentedTextWriterWrapper(textWriter));
                    files.Add(new CodeFile
                    {
                        FileName = nameSpace.Name + ".lua",
                        Content = textWriter.ToString(),
                        Header = CsLuaFileHeader
                    });
                }
            }

            var additionalFiles = new List<CodeFile>();
            files.ForEach(file =>
            {
                Match match = Regex.Match(file.Content, @"^--TargetFile: *(\w*\.lua)");
                if (!match.Success) return;

                string targetfileName = match.Groups[1].Value;
                CodeFile targetFile =
                    files.FirstOrDefault(otherFile => otherFile.FileName.Equals(targetfileName)) ??
                    additionalFiles.FirstOrDefault(otherFile => otherFile.FileName.Equals(targetfileName));
                if (targetFile == null)
                {
                    targetFile = new CodeFile {FileName = targetfileName, Content = file.Content.Substring(match.Length)};
                    additionalFiles.Add(targetFile);
                }
                else
                {
                    targetFile.Content += "\n" + file.Content.Substring(match.Length);
                }
                file.Ignore = true;
            });
            files.AddRange(additionalFiles);

            if (requiresCsLuaMetaHeader)
            {
                var mainFile = files.FirstOrDefault(file => file.FileName.Equals(name + ".lua"));
                if (mainFile == null)
                {
                    throw new ConverterException(String.Format("Project {0} has a RequiresCsLuaHeader attribute, but does not have a file named {0}.lua to add it to.", name));
                }
                mainFile.Content = CsLuaMetaReader.GetReferenceString() + "\n" + mainFile.Content;
            }

            return files.Where(file => file.Ignore != true).ToList();
        }
    }
}