﻿namespace CsLuaConverter.Providers.TypeKnowledgeRegistry
{
    public class TypeKnowledgeRegistry : ITypeKnowledgeRegistry
    {
        public TypeKnowledge CurrentType { get; set; }
        public TypeKnowledge ExpectedType { get; set; }
        public TypeKnowledge[] PossibleMethods { get; set; }
    }
}