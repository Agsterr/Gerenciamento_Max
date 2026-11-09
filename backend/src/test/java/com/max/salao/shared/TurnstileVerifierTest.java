package com.max.salao.shared;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

class TurnstileVerifierTest {

    private final ObjectMapper json = new ObjectMapper();

    @Test
    void semChavesOCaptchaFicaDesligadoENaoExigeToken() {
        var v = new TurnstileVerifier("", "", json);
        assertThat(v.enabled()).isFalse();
        assertThat(v.siteKey()).isEmpty();
        assertThatCode(() -> v.verify(null, "1.2.3.4")).doesNotThrowAnyException();
    }

    @Test
    void comApenasUmaDasChavesContinuaDesligado() {
        assertThat(new TurnstileVerifier("segredo", "", json).enabled()).isFalse();
        assertThat(new TurnstileVerifier("", "publica", json).enabled()).isFalse();
    }

    @Test
    void ligadoExigeTokenAntesDeFalarComACloudflare() {
        var v = new TurnstileVerifier("segredo", "publica", json);
        assertThat(v.enabled()).isTrue();
        assertThat(v.siteKey()).isEqualTo("publica");
        assertThatThrownBy(() -> v.verify("  ", "1.2.3.4")).isInstanceOf(BusinessException.class);
        assertThatThrownBy(() -> v.verify(null, "1.2.3.4")).isInstanceOf(BusinessException.class);
    }
}
