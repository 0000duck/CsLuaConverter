﻿namespace CsLuaConverterTests
{
    using System;
    using System.IO;

    public class ComparingTextWriter : TextWriter
    {
        private StringWriter innerWriter;
        private int currentLine;
        private int currentOffset;
        private string[] comparingLines;

        public ComparingTextWriter(string stringToCompare)
        {
            this.comparingLines = stringToCompare.Split('\n');
            this.currentLine = 0;
            this.currentOffset = 0;
            this.innerWriter = new StringWriter();
        }

        public override System.Text.Encoding Encoding { get; }

        public override void Write(string str)
        {
            this.innerWriter.Write(str);
            this.Compare(str, false);
        }

        public override void WriteLine(string str)
        {
            this.innerWriter.WriteLine(str);
            this.Compare(str, true);
        }

        public override string ToString()
        {
            return this.innerWriter.ToString();
        }

        private void Compare(string str, bool newLineAtEnd)
        {
            var newLines = str.Split('\n');

            for (var i = 0; i < newLines.Length; i++)
            {
                this.ValidateString(newLines[i]);

                if (i < newLines.Length - 1 || newLineAtEnd)
                {
                    this.currentLine++;
                    this.currentOffset = 0;
                }
                else
                {
                    this.currentOffset += newLines[i].Length;
                }
            }
        }

        private void ValidateString(string actualString)
        {
            var expectedString = this.comparingLines[this.currentLine].Substring(this.currentOffset,
                System.Math.Min(actualString.Length, this.comparingLines[this.currentLine].Length - this.currentOffset));

            if (expectedString == actualString)
            {
                return;
            }

            throw new Exception($"String missmatch. Line {this.currentLine} Expected '{expectedString}', got '{actualString}'.");
        }
    }
}