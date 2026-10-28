package __APPLICATION_ID__.core

import kotlin.test.Test
import kotlin.test.assertEquals

class GreetingTest {
    @Test
    fun headlineNamesTheApp() {
        assertEquals("Hello from __APP_NAME__", Greeting.headline("__APP_NAME__"))
    }
}
