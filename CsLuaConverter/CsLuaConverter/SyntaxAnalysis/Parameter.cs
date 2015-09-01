﻿namespace CsLuaConverter.SyntaxAnalysis
{
    using System.CodeDom.Compiler;
    using CsLuaConverter.Providers;
    using CsLuaConverter.Providers.TypeProvider;
    using Microsoft.CodeAnalysis;
    using Microsoft.CodeAnalysis.CSharp.Syntax;

    internal class Parameter : ILuaElement
    {
        public VariableType Type;
        public string Name;
        public bool IsParam;

        public void WriteLua(IndentedTextWriter textWriter, IProviders providers)
        {
            providers.NameProvider.AddToScope(new ScopeElement(this.Name));
            textWriter.Write(this.Name);
        }

        public SyntaxToken Analyze(SyntaxToken token)
        {
            if (token.Text.Equals("params"))
            {
                token = token.GetNextToken();
                this.IsParam = true;
            }

            if (!(token.Parent is ParameterSyntax))
            {
                this.Type = new VariableType();
                token = this.Type.Analyze(token);
                token = token.GetNextToken();
            }

            // ParameterSyntax
            LuaElementHelper.CheckType(typeof(ParameterSyntax), token.Parent);
            this.Name = token.Text;
            return token.GetNextToken();
        }
    }
}