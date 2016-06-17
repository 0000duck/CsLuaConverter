﻿namespace CsLuaConverter.CodeTreeLuaVisitor.Member
{
    using CodeTree;
    using Microsoft.CodeAnalysis.CSharp;
    using Providers;

    public class EnumMemberDeclarationVisitor : BaseVisitor
    {
        private readonly string index;

        public EnumMemberDeclarationVisitor(CodeTreeBranch branch) : base(branch)
        {
            this.ExpectKind(0, SyntaxKind.IdentifierToken);
            this.index = ((CodeTreeLeaf) this.Branch.Nodes[0]).Text;
        }

        public override void Visit(IIndentedTextWriterWrapper textWriter, IProviders providers)
        {
            textWriter.Write($"[\"{this.index}\"] = ");
            this.WriteValue(textWriter);
        }

        public void WriteAsDefault(IIndentedTextWriterWrapper textWriter, IProviders providers)
        {
            textWriter.Write("__default = ");
            this.WriteValue(textWriter);
        }

        private void WriteValue(IIndentedTextWriterWrapper textWriter)
        {
            textWriter.Write($"\"{this.index}\"");
        }
    }
}