using UnityEngine;

namespace Game.Combat
{
    /// <summary>
    /// Main combat controller. Handles damage resolution.
    /// </summary>
    public sealed class CombatSystem : MonoBehaviour
    {
        [SerializeField] private int maxActionPoints = 3;

        public int MaxActionPoints => maxActionPoints;

        public CombatResult StartCombat(Entity attacker, Entity defender)
        {
            return new CombatResult();
        }

        private void ApplyDamage(Entity e, int amount) { }
    }
}
