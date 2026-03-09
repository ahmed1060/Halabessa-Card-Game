using Studio.OverOne.DragMe.Data.Abstractions;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace Studio.OverOne.DragMe.Demo
{
    public class InventoryController : MonoBehaviour
    {
        #region " Inspector Variables "

        [SerializeField] private List<Components.DragMe> InventorySlots = new List<Components.DragMe>();

        #endregion

        public void FindAvailableInventorySlot(IResetEventData eventData)
        {
            Components.DragMe lSlot = InventorySlots.FirstOrDefault(x => x.Available);
            eventData.ResetComponent.Parent = lSlot.transform;
        }
    }
}