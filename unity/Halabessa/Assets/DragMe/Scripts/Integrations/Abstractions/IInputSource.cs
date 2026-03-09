namespace Studio.OverOne.DragMe.Integrations.Abstractions
{
    public interface IInputSource 
    {
        bool Grab { get; }

        bool Hold { get; }

        bool Release { get; }
    }
}