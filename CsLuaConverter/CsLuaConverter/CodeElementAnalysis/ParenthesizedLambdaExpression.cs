﻿namespace CsLuaConverter.CodeElementAnalysis
{
    using Microsoft.CodeAnalysis;
    using Microsoft.CodeAnalysis.CSharp;

    public class ParenthesizedLambdaExpression : BaseElement
    {
        public override SyntaxToken Analyze(SyntaxToken token)
        {
            ExpectKind(SyntaxKind.ParenthesizedLambdaExpression, token.Parent.GetKind());
            ExpectKind(SyntaxKind.EqualsGreaterThanToken, token.GetKind());

            return token;
        }
    }
}