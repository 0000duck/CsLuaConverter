﻿namespace CsLuaConverter.CodeTreeLuaVisitor.Expression
{
    using System;
    using System.Linq;
    using System.Reflection;
    using CodeTree;
    using Lists;
    using Providers;
    using Providers.TypeKnowledgeRegistry;

    public class InvocationExpressionVisitor : BaseVisitor
    {
        private readonly BaseVisitor target;
        private readonly ArgumentListVisitor argumentList;
        public InvocationExpressionVisitor(CodeTreeBranch branch) : base(branch)
        {
            this.target = this.CreateVisitor(0);
            this.argumentList = (ArgumentListVisitor) this.CreateVisitor(1);
        }

        public override void Visit(IIndentedTextWriterWrapper textWriter, IProviders providers)
        {
            textWriter.Write("(");
            this.target.Visit(textWriter, providers);

            if (providers.TypeKnowledgeRegistry.PossibleMethods != null)
            {
                var argumentListWriter = textWriter.CreateTextWriterAtSameIndent();
                this.argumentList.Visit(argumentListWriter, providers);

                var method = providers.TypeKnowledgeRegistry.PossibleMethods.GetOnlyRemainingMethodOrThrow();

                var numGenerics = method.GetNumberOfMethodGenerics();

                if (!method.IsGetType())
                {
                    textWriter.Write($"_M_{numGenerics}_");

                    method.WriteSignature(textWriter, providers);

                    var writeMethodGenericsAction = providers.TypeKnowledgeRegistry.PossibleMethods.WriteMethodGenerics;
                    if (writeMethodGenericsAction != null)
                    {
                        writeMethodGenericsAction();
                    }
                    else if (numGenerics > 0)
                    {
                        WriteMethodGenerics(method.GetResolvedMethodGenerics(), textWriter, providers);
                    }
                }

                textWriter.Write(" % _M.DOT)");

                textWriter.AppendTextWriter(argumentListWriter);

                providers.TypeKnowledgeRegistry.CurrentType = method.GetReturnType();
            }
            else
            {
                var currentType = providers.TypeKnowledgeRegistry.CurrentType;

                if (!currentType.IsDelegate())
                {
                    throw new VisitorException("Cannot invoke non delegate.");
                }

                var invoke = currentType.GetTypeObject().GetMember("Invoke").OfType<MethodBase>().First();
                var method = new MethodKnowledge(invoke);
                providers.TypeKnowledgeRegistry.PossibleMethods = new PossibleMethods(new []{ method });
                providers.TypeKnowledgeRegistry.CurrentType = null;

                textWriter.Write(" % _M.DOT)");
                this.argumentList.Visit(textWriter, providers);

                providers.TypeKnowledgeRegistry.CurrentType = method.GetReturnType();
            }

            providers.TypeKnowledgeRegistry.PossibleMethods = null;
        }

        private static void WriteMethodGenerics(TypeKnowledge[] genericTypes, IIndentedTextWriterWrapper textWriter, IProviders providers)
        {
            textWriter.Write("[{");
            var first = true;
            genericTypes.ToList().ForEach(genericType =>
            {
                if (first)
                {
                    first = false;
                }
                else
                {
                    textWriter.Write(", ");
                }

                genericType.WriteAsType(textWriter, providers);
            });
            textWriter.Write("}]");
        }
    }
}