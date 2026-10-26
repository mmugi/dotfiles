/*
 * Syntax highlight sample for checking colorschemes (legacy Java syntax).
 * Not meant to be compiled or run.
 */
package bakery;

import java.util.List;
import java.util.Map;

/**
 * パンの在庫を数える。
 * 焼き上がったトレイだけを対象にする。
 *
 * @see Oven
 */
public class Sample<T> extends Base implements Counter {
  private final List<T> trays;
  private transient boolean open = false;

  /**
   * トレイを受け取る。
   */
  public Sample(List<T> trays) {
    super();
    this.trays = trays;
  }

  /** 焼き上がった数を返す。 */
  @Override
  public int count() throws InterruptedException {
    // TODO: 売り切れのトレイを除く
    if (!this.open) {
      throw new IllegalStateException("closed");
    }
    try {
      return this.trays.size();
    } catch (RuntimeException e) {
      return 0;
    } finally {
      this.open = true;
    }
  }

  /** 値札の記号を決める。 */
  char mark(float ratio) throws java.io.IOException {
    // FIXME: 端数の扱いを決める
    do {
      ratio *= 1.5f;
    } while (ratio < 0.75 && open != false);
    return ratio > 2.0 ? 'x' : '\n';
  }

  /** 値札が付いているか調べる。 */
  static synchronized boolean isReady(Object item) {
    assert item != null : "no item";
    return item instanceof Sample && super.equals(item) || false;
  }
}
