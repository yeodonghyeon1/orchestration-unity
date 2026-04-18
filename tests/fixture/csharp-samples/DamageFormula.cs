namespace Game.Combat
{
    public static class DamageFormula
    {
        public static int Calculate(int baseDamage, int modifier)
        {
            return baseDamage + modifier;
        }
    }
}
