﻿
namespace CsLuaConverter.Providers.NameProvider
{
    using System.Collections.Generic;
    using TypeProvider;

    public interface INameProvider
    {
        List<ScopeElement> CloneScope();
        void SetScope(List<ScopeElement> scope);
        void AddToScope(ScopeElement element);
        ScopeElement GetScopeElement(string name);
        void AddAllInheritedMembersToScope(string typeName);
        IEnumerable<string> LookupVariableNameSplitted(IEnumerable<string> names, int numGenerics);
    }
}
