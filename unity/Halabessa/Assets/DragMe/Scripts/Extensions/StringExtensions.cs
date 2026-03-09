namespace Studio.OverOne.DragMe.Extensions
{
    public static class StringExtensions 
    {
        public static string Fmt(this string source, params string[] segments)
        {
            return string.Format(source, segments);
        }
    }
}