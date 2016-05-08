﻿namespace CsLuaConverter.Providers.TypeKnowledgeRegistry
{
    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Linq;
    using System.Reflection;
    using System.Runtime.CompilerServices;

    [DebuggerDisplay("MethodKnowledge: {method}")]
    public class MethodKnowledge : IKnowledge
    {
        private readonly bool isExtension;
        private readonly MethodBase method;
        private readonly Type[] inputTypes;
        private readonly Type returnType;

        public MethodKnowledge(MethodBase method)
        {
            this.method = method;
            this.isExtension = this.method.GetCustomAttribute<ExtensionAttribute>() != null;
        }

        public MethodKnowledge(Type returnType, params Type[] inputTypes)
        {
            this.returnType = returnType;
            this.inputTypes = inputTypes;
        }

        public MethodKnowledge()
        {
            this.returnType = typeof(void);
            this.inputTypes = new Type[] {};
        }

        public TypeKnowledge ToTypeKnowledge()
        {
            return new TypeKnowledge(this.method);
        }

        public int GetNumberOfMethodGenerics()
        {
            return this.method?.GetGenericArguments().Length ?? 0;
        }

        public int GetNumberOfArgs()
        {
            return this.GetInputParameterTypes().Length;
        }

        public bool IsParams()
        {
            return this.method?.GetParameters().LastOrDefault()?.GetCustomAttributes(typeof(ParamArrayAttribute), false).Any() ?? false;
        }

        public bool FitsArguments(Type[] types)
        {
            var isParams = this.IsParams();
            var parameterTypes = this.GetInputParameterTypes();

            for (var index = 0; index < types.Length; index++)
            {
                var type = types[index];

                if (type == null)
                {
                    continue;
                }

                var parameter = parameterTypes[Math.Min(index, parameterTypes.Length - 1)];

                if (isParams && index >= parameterTypes.Length)
                {
                    var paramType =
                        parameter.GetInterface(typeof (IEnumerable<object>).Name).GetGenericArguments().Single();
                    if (!paramType.IsAssignableFrom(type))
                    {
                        return false;
                    }
                }
                else
                {
                    if (!parameter.IsAssignableFrom(type))
                    {
                        return false;
                    }
                }
            }

            return true;
        }

        public TypeKnowledge[] GetInputArgs()
        {
            return this.GetInputParameterTypes().Select(p => new TypeKnowledge(p)).ToArray();
        }

        public TypeKnowledge GetReturnType()
        {
            
            if (this.method != null)
            {
                var methodInfo = this.method as MethodInfo;
                return methodInfo != null
                    ? new TypeKnowledge(methodInfo.ReturnType)
                    : null;
            }

            return new TypeKnowledge(this.returnType);
        }


        private Type[] GetInputParameterTypes()
        {
            if (this.method != null)
            {
                return this.method.GetParameters().Skip(this.isExtension ? 1 : 0).Select(p => p.ParameterType).ToArray();
            }

            return this.inputTypes;
        }

        public int? GetScore(Type[] types)
        {
            var isParams = this.IsParams();
            var parameters = this.GetInputParameterTypes();

            var score = 0;
            for (var index = 0; index < parameters.Length; index++)
            {
                var type = types[index];

                if (type == null)
                {
                    continue;
                }

                var parameter = parameters[Math.Min(index, parameters.Length - 1)];

                int? parScore = 0;
                if (isParams && index >= parameters.Length)
                {
                    var paramType = parameter.GetInterface(typeof(IEnumerable<object>).Name).GetGenericArguments().Single();
                    parScore = ScoreForHowWellOtherTypeFits(paramType, type);
                }
                else
                {
                    parScore = ScoreForHowWellOtherTypeFits(parameter, type);
                }

                if (parScore == null)
                {
                    return null;
                }

                score += (int) parScore;
            }

            return score;
            
        }

        private static int? ScoreForHowWellOtherTypeFits(Type type, Type otherType)
        {
            if (type.IsGenericParameter)
            {
                throw new Exception("Cannot perform action on a generic type.");
            }

            var c = 0;

            while (!type.IsAssignableFrom(otherType))
            {
                otherType = otherType.BaseType;

                if (otherType == null)
                {
                    return null;
                }

                c++;
            }

            return type == otherType ? c : c + 1;
        }


        public bool FilterByNumberOfLambdaArgs(int?[] numOfArgs)
        {
            var inputParameters = this.GetInputParameterTypes();
            for (var index = 0; index < this.GetInputParameterTypes().Length; index++)
            {
                var numArgs = numOfArgs[index];

                if (numArgs == null)
                {
                    continue;
                }

                var inputParameterType = inputParameters[index];

                var del = GetDelegate(inputParameterType);

                if (del == null)
                {
                    return false;
                }

                var lambdaInputCount = del.GetMethod("Invoke").GetParameters().Length;
                if (lambdaInputCount != numArgs)
                {
                    return false;
                }
            }

            return true;
        }

        private static System.Type GetDelegate(System.Type type)
        {
            if (type.BaseType == typeof(MulticastDelegate))
            {
                return type;
            }

            return type.BaseType?.BaseType != null ? GetDelegate(type.BaseType) : null;
        }
    }
}