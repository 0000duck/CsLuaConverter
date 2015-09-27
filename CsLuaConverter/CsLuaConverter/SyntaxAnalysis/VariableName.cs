﻿namespace CsLuaConverter.SyntaxAnalysis
{
    using System;
    using System.CodeDom.Compiler;
    using System.Collections.Generic;
    using System.Linq;
    using CsLuaConverter.Providers;
    using CsLuaConverter.Providers.TypeProvider;
    using Microsoft.CodeAnalysis;
    using Microsoft.CodeAnalysis.CSharp.Syntax;

    internal class VariableName : ILuaElement
    {
        public readonly List<string> Names = new List<string>();
        private readonly bool addToScope;
        private readonly bool isClassVar;
        private readonly bool resolveAsFullName;
        private readonly bool isTypeReference;
        private bool isInitialization;
        public GenericsParsing Generics;

        public VariableName(bool resolveAsFullName)
        {
            this.resolveAsFullName = resolveAsFullName;
        }

        public VariableName(bool resolveAsFullName, bool addToScope, bool isClassVar)
        {
            this.addToScope = addToScope;
            this.resolveAsFullName = resolveAsFullName;
            this.isClassVar = isClassVar;
        }

        public VariableName(bool resolveAsFullName, bool addToScope, bool isClassVar, bool isTypeReference)
        {
            this.addToScope = addToScope;
            this.resolveAsFullName = resolveAsFullName;
            this.isClassVar = isClassVar;
            this.isTypeReference = isTypeReference;
        }

        public void WriteLua(IndentedTextWriter textWriter, IProviders providers)
        {
            if (this.isTypeReference)
            {
                textWriter.Write(providers.TypeProvider.LookupType(this.Names));
                return;
            }

            if (this.addToScope)
            {
                if (this.Names.Count != 1)
                    throw new Exception("Cannot add multi name variable to scope");
                providers.NameProvider.AddToScope(new ScopeElement(this.Names.First()));
            }

            string s = string.Empty;
            if (this.resolveAsFullName)
            {
                var fullRef = providers.NameProvider.LookupVariableName(this.Names, this.isClassVar);
                var dotCount = fullRef.Split('.').Length -1;
                if (dotCount > 0)
                {
                    textWriter.Write(
                        //"(" +
                        new string('(', dotCount) +
                        fullRef.Replace(".", "%CsLuaMeta.dot).") //+
                        //")" 
                    );
                }
                else
                {
                    textWriter.Write(fullRef);
                }

                if (this.Generics != null)
                {
                    textWriter.Write("[");
                    this.Generics.WriteLua(textWriter, providers);
                    textWriter.Write("]");
                }
                
                return;
            }
            textWriter.Write(string.Join(".", this.Names));
        }

        public SyntaxToken Analyze(SyntaxToken token)
        {
            LuaElementHelper.CheckType(new[]
            {
                typeof(IdentifierNameSyntax), typeof(VariableDeclaratorSyntax), typeof(GenericNameSyntax),
                typeof(PredefinedTypeSyntax)
            }, token.Parent);
            this.Names.Add(token.Text);

            SyntaxToken prevToken = token.GetPreviousToken();
            if (prevToken.Parent is ObjectCreationExpressionSyntax)
            {
                this.isInitialization = true;
            }

            while (token.GetNextToken().Parent is MemberAccessExpressionSyntax
                   || token.GetNextToken().Parent is QualifiedNameSyntax)
            {
                token = token.GetNextToken();
                token = token.GetNextToken();
                LuaElementHelper.CheckType(new[] {typeof(IdentifierNameSyntax), typeof(GenericNameSyntax)},
                    token.Parent);
                this.Names.Add(token.Text);
            }

            if (token.GetNextToken().Parent is ArrayRankSpecifierSyntax) // []
            {
                token = token.GetNextToken();
                token = token.GetNextToken();
            }

            if (token.GetNextToken().Parent is TypeArgumentListSyntax && token.GetNextToken().Text.Equals("<")) // <T>
            {
                token = token.GetNextToken();
                this.Generics = new GenericsParsing();
                token = this.Generics.Analyze(token);
            }

            if (token.GetNextToken().Parent is TypeParameterConstraintClauseSyntax) // where
            {
                while (token.Text != "{" && token.Text != ";")
                {
                    token = token.GetNextToken();
                }
            }

            return token;
        }

        public bool IsGenerics(IProviders providers)
        {
            return this.Names.Count == 1 && providers.GenericsRegistry.IsGeneric(this.Names.Single());
        }

        public ITypeResult GetTypeResult(IProviders providers)
        {
            return this.IsGenerics(providers) ? new NativeTypeResult(this.Names.Single()) : providers.TypeProvider.LookupType(this.Names);
        }
    }
}