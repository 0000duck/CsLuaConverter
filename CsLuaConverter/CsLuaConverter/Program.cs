﻿namespace CsLuaConverter
{
    using System;
    using System.Diagnostics;
    using System.Globalization;
    using System.IO;
    using System.Threading.Tasks;
    using CodeElementAnalysis;
    using LuaVisitor;
    using Microsoft.CodeAnalysis;
    using Microsoft.CodeAnalysis.MSBuild;

    internal class Program
    {
        private static int Main(string[] args)
        {
            if (Debugger.IsAttached)
            {
                Convert(args[0], args[1]);
                return 0;
            }
            else
            { 
                Console.WriteLine("Started CsToLua converter.");
                try
                {
                    Convert(args[0], args[1]);
                    return 0;
                }
                catch (Exception exception)
                {
                    Console.WriteLine(string.Format(CultureInfo.InvariantCulture, "Exception: {0}", exception.Message));
                    return -1;
                }
            }
        }

        private static void Convert(string solutionPath, string wowPath)
        {
            var stopWatch = new Stopwatch();
            stopWatch.Start();
            var solution = GetSolution(solutionPath);
            var providers = new Providers.Providers(solution);

            ISyntaxAnalyser analyzer = new Analyzer(new LuaDocumentVisitor());

            var solutionHandler = new SolutionHandler(analyzer);
            var addOns = solutionHandler.GenerateAddOnsFromSolution(solution, providers);

            foreach (var addon in addOns)
            {
                addon.DeployAddOn(wowPath);
            }

            stopWatch.Stop();
            
            Console.WriteLine("Lua converting successfull. Time: {0}.{1} sec.", stopWatch.Elapsed.Seconds, stopWatch.Elapsed.Milliseconds);
        }

        private static Solution GetSolution(string path)
        {
            var solutionFile = new FileInfo(path);
            if (!solutionFile.Exists)
            {
                throw new ConverterException(string.Format("Could not load the solution file: {0}", solutionFile.FullName));
            }

            MSBuildWorkspace workspace = MSBuildWorkspace.Create();
            Task<Solution> loadSolution = workspace.OpenSolutionAsync(path);
            loadSolution.Wait();
            return loadSolution.Result;
        }
    }
}