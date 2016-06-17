﻿namespace CsLuaConverter.CodeTreeLuaVisitor.Expression
{
    using CodeTree;
    using Microsoft.CodeAnalysis.CSharp;
    using Providers;
    using Type;

    public class CastExpressionVisitor : BaseVisitor
    {
        private readonly ITypeVisitor typeVisitor;
        private readonly IVisitor innerVisitor;

        public CastExpressionVisitor(CodeTreeBranch branch) : base(branch)
        {
            this.ExpectKind(0, SyntaxKind.OpenParenToken);
            this.ExpectKind(2, SyntaxKind.CloseParenToken);
            this.typeVisitor = (ITypeVisitor)this.CreateVisitor(1);
            this.innerVisitor = this.CreateVisitor(3);
        }

        public override void Visit(IIndentedTextWriterWrapper textWriter, IProviders providers)
        {
            this.innerVisitor.Visit(textWriter, providers);
            providers.TypeKnowledgeRegistry.CurrentType = this.typeVisitor.GetType(providers);
        }
    }
}