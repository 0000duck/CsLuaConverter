﻿namespace CsLuaConverter.LuaVisitor
{
    using System.CodeDom.Compiler;
    using CodeElementAnalysis;
    using Providers;

    public class ArrayVisitor : IVisitor<ArrayCreationExpression>, IVisitor<ArrayInitializerExpression>, IVisitor<ImplicitArrayCreationExpression>
    {
        public void Visit(ArrayCreationExpression element, IndentedTextWriter textWriter, IProviders providers)
        {
            textWriter.Write("(System.Array[{");
            if (element.ElementType is PredefinedType)
            {
                ((PredefinedType)element.ElementType).IsArray = false;
            }

            if (element.ElementType is GenericName)
            {
                ((GenericName)element.ElementType).IsArray = false;
            }

            TypeOfExpressionVisitor.WriteTypeReference(element.ElementType, textWriter, providers);
            textWriter.Write("}]() % _M.DOT).__Initialize");

            VisitorList.Visit(element.Initializer);
        }

        public void Visit(ArrayInitializerExpression element, IndentedTextWriter textWriter, IProviders providers)
        {
            textWriter.Write("({");

            if (element.ContainedElements.Count > 0)
            {
                textWriter.Write("[0]=");

                foreach (var containedElementList in element.ContainedElements)
                {
                    foreach (var baseElement in containedElementList)
                    {
                        VisitorList.Visit(baseElement);
                    }
                    
                    textWriter.Write(",");
                }
            }

            textWriter.Write("})");
        }

        public void Visit(ImplicitArrayCreationExpression element, IndentedTextWriter textWriter, IProviders providers)
        {
            textWriter.Write("ImplicitArray");
            VisitorList.Visit(element.Initializer);
        }
    }
}