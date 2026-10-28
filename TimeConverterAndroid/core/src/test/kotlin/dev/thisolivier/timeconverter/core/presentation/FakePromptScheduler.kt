package dev.thisolivier.timeconverter.core.presentation

/** A manual clock for the debounce: nothing fires until the test advances time. */
class FakePromptScheduler : PromptScheduler {
    private class Entry(val dueAtMillis: Long, val action: () -> Unit) {
        var isCancelled = false
    }

    var currentMillis: Long = 0
        private set
    private val entries = mutableListOf<Entry>()

    val pendingCount: Int get() = entries.count { !it.isCancelled }

    override fun schedule(delayMillis: Long, action: () -> Unit): ScheduledPrompt {
        val entry = Entry(currentMillis + delayMillis, action)
        entries += entry
        return ScheduledPrompt { entry.isCancelled = true }
    }

    fun advanceBy(millis: Long) {
        currentMillis += millis
        val due = entries.filter { it.dueAtMillis <= currentMillis }
        entries -= due.toSet()
        due.filterNot { it.isCancelled }.forEach { it.action() }
    }
}
