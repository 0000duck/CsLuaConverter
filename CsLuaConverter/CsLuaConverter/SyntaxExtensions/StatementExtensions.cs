﻿namespace CsLuaConverter.SyntaxExtensions
{
    using CsLuaConverter.CodeTreeLuaVisitor;
    using CsLuaConverter.Context;
    using Microsoft.CodeAnalysis.CSharp;
    using Microsoft.CodeAnalysis.CSharp.Syntax;

    public static class StatementExtensions
    {
        private static readonly TypeSwitch TypeSwitch = new TypeSwitch(
            (syntax, textWriter, context) =>
                {
                    SyntaxVisitorBase<MemberAccessExpressionSyntax>.VisitNode((CSharpSyntaxNode)syntax, textWriter, context);
                    //throw new Exception($"Could not find extension method for statementSyntax {obj.GetType().Name}.");
                })
            .Case<BlockSyntax>(Write)
            .Case<ExpressionStatementSyntax>(Write)
            .Case<SwitchStatementSyntax>(SwitchExtensions.Write)
            .Case<BreakStatementSyntax>(Write)
            .Case<IfStatementSyntax>(Write)
            .Case<ElseClauseSyntax>(Write);

        /*
        
        CheckedStatementSyntax
        ContinueStatementSyntax
        DoStatementSyntax
        EmptyStatementSyntax
        FixedStatementSyntax
        ForEachStatementSyntax
        ForStatementSyntax
        GotoStatementSyntax
        IfStatementSyntax
        LabeledStatementSyntax
        LocalDeclarationStatementSyntax
        LockStatementSyntax
        ReturnStatementSyntax
        ThrowStatementSyntax
        TryStatementSyntax
        UnsafeStatementSyntax
        UsingStatementSyntax
        WhileStatementSyntax
        YieldStatementSyntax
        */

        public static void Write(this StatementSyntax syntax, IIndentedTextWriterWrapper textWriter, IContext context)
        {
            TypeSwitch.Write(syntax, textWriter, context);
        }

        public static void Write(this BlockSyntax syntax, IIndentedTextWriterWrapper textWriter, IContext context)
        {
            textWriter.Indent++;
            syntax.Statements.Write(Write, textWriter, context);
            textWriter.Indent--;
        }

        public static void Write(this ExpressionStatementSyntax syntax, IIndentedTextWriterWrapper textWriter, IContext context)
        {
            syntax.Expression.Write(textWriter, context);
            textWriter.WriteLine(";");
        }

        public static void Write(this BreakStatementSyntax syntax, IIndentedTextWriterWrapper textWriter, IContext context)
        {
            textWriter.WriteLine("break;");
        }

        public static void Write(this IfStatementSyntax syntax, IIndentedTextWriterWrapper textWriter, IContext context)
        {
            textWriter.Write("if (");
            syntax.Condition.Write(textWriter, context);
            textWriter.WriteLine(") then");

            syntax.Statement.Write(textWriter, context);

            if (syntax.Else != null)
            {
                syntax.Else.Write(textWriter, context);
            }
            else
            {
                textWriter.WriteLine("end");
            }
        }

        public static void Write(this ElseClauseSyntax syntax, IIndentedTextWriterWrapper textWriter, IContext context)
        {
            textWriter.Write("else");

            if (syntax.Statement is IfStatementSyntax)
            {
                syntax.Statement.Write(textWriter, context);
            }
            else
            {
                textWriter.WriteLine("");
                syntax.Statement.Write(textWriter, context);
                textWriter.WriteLine("end");
            }
        }
    }
}